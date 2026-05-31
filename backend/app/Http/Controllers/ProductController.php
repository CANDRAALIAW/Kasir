<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\ActivityLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $branchId = $request->query('branch_id');
        $query = Product::query();

        if ($branchId) {
            $query->where('branch_id', $branchId);
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string',
            'price' => 'required|numeric',
            'stock' => 'required|integer',
            'minimum_stock' => 'nullable|integer|min:0',
            'branch_id' => 'required|exists:branches,id',
            'image' => 'nullable|image|mimes:jpeg,png,jpg|max:2048',
        ]);

        $data = $request->only(['name', 'description', 'price', 'stock', 'minimum_stock', 'branch_id']);

        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('products', 'public');
            $data['image_path'] = $path;
        }

        $product = Product::create($data);

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Create Product',
            'description' => "Membuat produk baru: {$product->name}",
            'properties' => $product->toArray(),
            'ip_address' => $request->ip(),
        ]);

        return response()->json($product, 201);
    }

    public function update(Request $request, $id)
    {
        $product = Product::findOrFail($id);

        $request->validate([
            'name' => 'string',
            'price' => 'numeric',
            'stock' => 'integer',
            'minimum_stock' => 'nullable|integer|min:0',
            'image' => 'nullable|image|mimes:jpeg,png,jpg|max:2048',
        ]);

        $data = $request->only(['name', 'description', 'price', 'stock', 'minimum_stock', 'branch_id']);
        $oldProduct = $product->toArray();

        if ($request->hasFile('image')) {
            // Delete old image if exists
            if ($product->image_path) {
                Storage::disk('public')->delete($product->image_path);
            }
            $path = $request->file('image')->store('products', 'public');
            $data['image_path'] = $path;
        }

        $product->update($data);

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Update Product',
            'description' => "Memperbarui produk: {$product->name}",
            'properties' => [
                'old' => $oldProduct,
                'new' => $product->toArray(),
            ],
            'ip_address' => $request->ip(),
        ]);

        return response()->json($product);
    }

    public function destroy(Request $request, $id)
    {
        $product = Product::findOrFail($id);
        $productName = $product->name;
        $productData = $product->toArray();

        if ($product->image_path) {
            Storage::disk('public')->delete($product->image_path);
        }
        $product->delete();

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Delete Product',
            'description' => "Menghapus produk: {$productName}",
            'properties' => $productData,
            'ip_address' => $request->ip(),
        ]);

        return response()->json(['message' => 'Product deleted']);
    }
}

