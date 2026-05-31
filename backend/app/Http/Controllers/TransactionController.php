<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Models\TransactionDetail;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TransactionController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'items' => 'required|array',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.qty' => 'required|integer|min:1',
            'total' => 'required|numeric',
            'payment_method' => 'string|in:tunai,qris,transfer',
            'payment_amount' => 'numeric',
            'change_amount' => 'numeric',
            'booking_id' => 'nullable|exists:cat_bookings,id',
        ]);

        $user = $request->user();
        
        if (!$user->branch_id) {
            return response()->json(['message' => 'User is not assigned to any branch'], 403);
        }

        return DB::transaction(function () use ($request, $user) {
            $invoiceNumber = 'INV-' . strtoupper(Str::random(10));

            $transaction = Transaction::create([
                'invoice_number' => $invoiceNumber,
                'user_id' => $user->id,
                'branch_id' => $user->branch_id,
                'total' => $request->total,
                'status' => 'completed',
                'payment_method' => $request->payment_method ?? 'tunai',
                'payment_amount' => $request->payment_amount ?? 0,
                'change_amount' => $request->change_amount ?? 0,
            ]);

            foreach ($request->items as $item) {
                $product = Product::lockForUpdate()->findOrFail($item['product_id']);
                
                $unitPrice = $product->price;
                $subtotal = $unitPrice * $item['qty'];

                TransactionDetail::create([
                    'transaction_id' => $transaction->id,
                    'product_id' => $product->id,
                    'price' => $unitPrice,
                    'qty' => $item['qty'],
                    'subtotal' => $subtotal,
                ]);

                // Services don't have stock management
                if (($product->type ?? 'product') !== 'service') {
                    if ($product->stock < $item['qty']) {
                        throw new \Exception("Insufficient stock for product: {$product->name}");
                    }

                    // Update stock
                    $product->decrement('stock', $item['qty']);

                    // Log stock movement
                    \App\Models\StockLog::create([
                        'product_id' => $product->id,
                        'user_id' => $user->id,
                        'type' => 'out',
                        'quantity' => $item['qty'],
                        'note' => "Sold via $invoiceNumber",
                    ]);

                    // Check if stock is now critically low
                    $updatedProduct = $product->fresh();
                    if ($updatedProduct->stock <= $updatedProduct->minimum_stock) {
                        // Create a mock WhatsApp Alert Log
                        \App\Models\ActivityLog::create([
                            'user_id' => $user->id,
                            'action' => 'WA Critical Stock Alert',
                            'description' => "[WA ALERT] Dikirim ke Admin: Stok produk '{$product->name}' kritis! Sisa stok saat ini: {$updatedProduct->stock} (Batas minimum: {$updatedProduct->minimum_stock}).",
                            'properties' => [
                                'product_id' => $product->id,
                                'product_name' => $product->name,
                                'remaining_stock' => $updatedProduct->stock,
                                'minimum_stock' => $updatedProduct->minimum_stock,
                                'recipient' => 'Admin Petshop (081234567890)',
                            ],
                            'ip_address' => $request->ip(),
                        ]);
                    }
                }
            }

            // Update linked cat booking if present
            if ($request->has('booking_id')) {
                $booking = \App\Models\CatBooking::find($request->booking_id);
                if ($booking) {
                    $booking->update([
                        'status' => 'completed',
                        'transaction_id' => $transaction->id,
                    ]);
                }
            }

            \App\Models\ActivityLog::create([
                'user_id' => $user->id,
                'action' => 'Checkout',
                'description' => "Kasir melakukan transaksi {$invoiceNumber} sebesar Rp " . number_format($request->total, 0, ',', '.'),
                'properties' => [
                    'transaction_id' => $transaction->id,
                    'invoice_number' => $invoiceNumber,
                    'total' => $request->total,
                ],
                'ip_address' => $request->ip(),
            ]);

            return response()->json([
                'message' => 'Transaction completed successfully',
                'transaction' => $transaction->load('details.product')
            ], 201);
        });
    }

    public function index(Request $request)
    {
        $branchId = $request->query('branch_id');
        $query = Transaction::with(['user', 'details.product', 'branch']);

        if ($branchId) {
            $query->where('branch_id', $branchId);
        }

        if ($request->has('search') && $request->search != '') {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('invoice_number', 'like', "%{$search}%")
                  ->orWhereHas('user', function($qu) use ($search) {
                      $qu->where('name', 'like', "%{$search}%");
                  });
            });
        }

        if ($request->has('payment_method') && $request->payment_method != '' && $request->payment_method != 'semua') {
            $query->where('payment_method', strtolower($request->payment_method));
        }

        if ($request->has('date_start') && $request->date_start != '') {
            $query->whereDate('created_at', '>=', $request->date_start);
        }

        if ($request->has('date_end') && $request->date_end != '') {
            $query->whereDate('created_at', '<=', $request->date_end);
        }

        $transactions = $query->orderBy('created_at', 'desc')->get();
        return \App\Http\Resources\TransactionResource::collection($transactions);
    }
}
