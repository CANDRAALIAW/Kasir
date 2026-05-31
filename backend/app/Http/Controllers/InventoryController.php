<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\StockLog;
use App\Models\ActivityLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InventoryController extends Controller
{
    public function restock(Request $request)
    {
        $request->validate([
            'product_id' => 'required|exists:products,id',
            'quantity' => 'required|integer|min:1',
            'note' => 'nullable|string',
        ]);

        return DB::transaction(function () use ($request) {
            $product = Product::findOrFail($request->product_id);
            $oldStock = $product->stock;
            $product->increment('stock', $request->quantity);

            StockLog::create([
                'product_id' => $product->id,
                'user_id' => $request->user()->id,
                'type' => 'in',
                'quantity' => $request->quantity,
                'note' => $request->note,
            ]);

            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Restock',
                'description' => "Restocked {$product->name} by {$request->quantity}",
                'properties' => [
                    'product_id' => $product->id,
                    'old_stock' => $oldStock,
                    'new_stock' => $product->stock,
                ],
                'ip_address' => $request->ip(),
            ]);

            return response()->json([
                'status' => 'success',
                'message' => 'Stock updated successfully',
                'current_stock' => $product->stock
            ]);
        });
    }

    public function history(Request $request)
    {
        $branchId = $request->query('branch_id');
        $query = StockLog::with(['product', 'user'])->latest();

        if ($branchId) {
            $query->whereHas('product', function ($q) use ($branchId) {
                $q->where('branch_id', $branchId);
            });
        }

        return response()->json([
            'status' => 'success',
            'data' => $query->paginate(20)
        ]);
    }
}
