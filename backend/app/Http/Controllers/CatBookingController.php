<?php

namespace App\Http\Controllers;

use App\Models\CatBooking;
use Illuminate\Http\Request;

class CatBookingController extends Controller
{
    public function index(Request $request)
    {
        $branchId = $request->query('branch_id');
        $query = CatBooking::with('product');

        if ($branchId) {
            $query->where('branch_id', $branchId);
        }

        if ($request->has('status') && $request->status != 'all') {
            $query->where('status', $request->status);
        }

        if ($request->has('search') && $request->search != '') {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('owner_name', 'like', "%{$search}%")
                  ->orWhere('cat_name', 'like', "%{$search}%")
                  ->orWhere('cat_breed', 'like', "%{$search}%");
            });
        }

        return response()->json($query->orderBy('created_at', 'desc')->get());
    }

    public function store(Request $request)
    {
        $request->validate([
            'owner_name' => 'required|string',
            'owner_phone' => 'required|string',
            'cat_name' => 'required|string',
            'cat_breed' => 'required|string',
            'booking_type' => 'required|string|in:grooming,pethotel',
            'product_id' => 'required|exists:products,id',
            'price' => 'required|numeric',
            'start_date' => 'required',
            'end_date' => 'nullable',
            'branch_id' => 'required|exists:branches,id',
        ]);

        $booking = CatBooking::create([
            'owner_name' => $request->owner_name,
            'owner_phone' => $request->owner_phone,
            'cat_name' => $request->cat_name,
            'cat_breed' => $request->cat_breed,
            'booking_type' => $request->booking_type,
            'product_id' => $request->product_id,
            'price' => $request->price,
            'start_date' => $request->start_date,
            'end_date' => $request->end_date,
            'status' => 'pending',
            'branch_id' => $request->branch_id,
        ]);

        return response()->json($booking->load('product'), 201);
    }

    public function update(Request $request, $id)
    {
        $booking = CatBooking::findOrFail($id);

        $request->validate([
            'owner_name' => 'string',
            'owner_phone' => 'string',
            'cat_name' => 'string',
            'cat_breed' => 'string',
            'booking_type' => 'string|in:grooming,pethotel',
            'product_id' => 'exists:products,id',
            'price' => 'numeric',
            'status' => 'string|in:pending,ongoing,completed,cancelled',
            'transaction_id' => 'nullable|exists:transactions,id',
        ]);

        $booking->update($request->only([
            'owner_name', 'owner_phone', 'cat_name', 'cat_breed',
            'booking_type', 'product_id', 'price', 'start_date', 'end_date',
            'status', 'transaction_id',
        ]));

        return response()->json($booking->load('product'));
    }

    public function destroy($id)
    {
        $booking = CatBooking::findOrFail($id);
        $booking->delete();

        return response()->json(['message' => 'Booking deleted']);
    }
}
