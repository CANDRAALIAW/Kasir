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
        $idCabang = $request->query('branch_id');
        $query = Product::query();

        if ($idCabang) {
            $query->where('id_cabang', $idCabang);
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        if ($request->has('name')) {
            $request->merge(['nama' => $request->name]);
        }
        if ($request->has('price')) {
            $request->merge(['harga' => $request->price]);
        }
        if ($request->has('stock')) {
            $request->merge(['stok' => $request->stock]);
        }
        if ($request->has('minimum_stock')) {
            $request->merge(['stok_minimum' => $request->minimum_stock]);
        }
        if ($request->has('description')) {
            $request->merge(['deskripsi' => $request->description]);
        }
        if ($request->has('branch_id')) {
            $request->merge(['id_cabang' => $request->branch_id]);
        }
        if ($request->hasFile('image') && !$request->hasFile('gambar')) {
            $request->files->set('gambar', $request->file('image'));
        }

        $request->validate([
            'nama' => 'required|string',
            'harga' => 'required|numeric',
            'stok' => 'required|integer',
            'stok_minimum' => 'nullable|integer|min:0',
            'id_cabang' => 'required|exists:cabang,id',
            'gambar' => 'nullable|image|mimes:jpeg,png,jpg|max:2048',
        ]);

        $data = $request->only(['nama', 'deskripsi', 'harga', 'stok', 'stok_minimum', 'id_cabang']);

        if ($request->hasFile('gambar')) {
            $path = $request->file('gambar')->store('produk', 'public');
            $data['path_gambar'] = $path;
        }

        $produk = Product::create($data);

        ActivityLog::create([
            'id_pengguna' => $request->user()->id,
            'aksi' => 'Buat Produk',
            'deskripsi' => "Membuat produk baru: {$produk->nama}",
            'properti' => $produk->toArray(),
            'alamat_ip' => $request->ip(),
        ]);

        return response()->json($produk, 201);
    }

    public function update(Request $request, $id)
    {
        $produk = Product::findOrFail($id);

        if ($request->has('name')) {
            $request->merge(['nama' => $request->name]);
        }
        if ($request->has('price')) {
            $request->merge(['harga' => $request->price]);
        }
        if ($request->has('stock')) {
            $request->merge(['stok' => $request->stock]);
        }
        if ($request->has('minimum_stock')) {
            $request->merge(['stok_minimum' => $request->minimum_stock]);
        }
        if ($request->has('description')) {
            $request->merge(['deskripsi' => $request->description]);
        }
        if ($request->has('branch_id')) {
            $request->merge(['id_cabang' => $request->branch_id]);
        }
        if ($request->hasFile('image') && !$request->hasFile('gambar')) {
            $request->files->set('gambar', $request->file('image'));
        }

        $request->validate([
            'nama' => 'string',
            'harga' => 'numeric',
            'stok' => 'integer',
            'stok_minimum' => 'nullable|integer|min:0',
            'gambar' => 'nullable|image|mimes:jpeg,png,jpg|max:2048',
        ]);

        $data = $request->only(['nama', 'deskripsi', 'harga', 'stok', 'stok_minimum', 'id_cabang']);
        $produkLama = $produk->toArray();

        if ($request->hasFile('gambar')) {
            // Hapus gambar lama jika ada
            if ($produk->path_gambar) {
                Storage::disk('public')->delete($produk->path_gambar);
            }
            $path = $request->file('gambar')->store('produk', 'public');
            $data['path_gambar'] = $path;
        }

        $produk->update($data);

        ActivityLog::create([
            'id_pengguna' => $request->user()->id,
            'aksi' => 'Perbarui Produk',
            'deskripsi' => "Memperbarui produk: {$produk->nama}",
            'properti' => [
                'lama' => $produkLama,
                'baru' => $produk->toArray(),
            ],
            'alamat_ip' => $request->ip(),
        ]);

        return response()->json($produk);
    }

    public function destroy(Request $request, $id)
    {
        $produk = Product::findOrFail($id);
        $namaProduk = $produk->nama;
        $dataProduk = $produk->toArray();

        if ($produk->path_gambar) {
            Storage::disk('public')->delete($produk->path_gambar);
        }
        $produk->delete();

        ActivityLog::create([
            'id_pengguna' => $request->user()->id,
            'aksi' => 'Hapus Produk',
            'deskripsi' => "Menghapus produk: {$namaProduk}",
            'properti' => $dataProduk,
            'alamat_ip' => $request->ip(),
        ]);

        return response()->json(['message' => 'Produk berhasil dihapus']);
    }
}
