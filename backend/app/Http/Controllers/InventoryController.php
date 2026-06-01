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
        if ($request->has('product_id')) {
            $request->merge(['id_produk' => $request->product_id]);
        }
        if ($request->has('quantity')) {
            $request->merge(['kuantitas' => $request->quantity]);
        }
        if ($request->has('note')) {
            $request->merge(['catatan' => $request->note]);
        }

        $request->validate([
            'id_produk' => 'required|exists:produk,id',
            'kuantitas' => 'required|integer|min:1',
            'catatan' => 'nullable|string',
        ]);

        return DB::transaction(function () use ($request) {
            $produk = Product::findOrFail($request->id_produk);
            $stokLama = $produk->stok;
            $produk->increment('stok', $request->kuantitas);

            StockLog::create([
                'id_produk' => $produk->id,
                'id_pengguna' => $request->user()->id,
                'jenis' => 'masuk',
                'kuantitas' => $request->kuantitas,
                'catatan' => $request->catatan,
            ]);

            ActivityLog::create([
                'id_pengguna' => $request->user()->id,
                'aksi' => 'Restock',
                'deskripsi' => "Restok {$produk->nama} sebanyak {$request->kuantitas}",
                'properti' => [
                    'id_produk' => $produk->id,
                    'stok_lama' => $stokLama,
                    'stok_baru' => $produk->stok,
                ],
                'alamat_ip' => $request->ip(),
            ]);

            return response()->json([
                'status' => 'berhasil',
                'message' => 'Stok berhasil diperbarui',
                'stok_sekarang' => $produk->stok
            ]);
        });
    }

    public function history(Request $request)
    {
        $idCabang = $request->query('branch_id');
        $query = StockLog::with(['produk', 'pengguna'])->latest();

        if ($idCabang) {
            $query->whereHas('produk', function ($q) use ($idCabang) {
                $q->where('id_cabang', $idCabang);
            });
        }

        return response()->json([
            'status' => 'berhasil',
            'data' => $query->paginate(20)
        ]);
    }
}
