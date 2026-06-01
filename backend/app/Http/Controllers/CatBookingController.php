<?php

namespace App\Http\Controllers;

use App\Models\CatBooking;
use Illuminate\Http\Request;

class CatBookingController extends Controller
{
    public function index(Request $request)
    {
        $idCabang = $request->query('branch_id');
        $query = CatBooking::with('produk');

        if ($idCabang) {
            $query->where('id_cabang', $idCabang);
        }

        if ($request->has('status') && $request->status != 'all') {
            $query->where('status', $request->status);
        }

        if ($request->has('search') && $request->search != '') {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('nama_pemilik', 'like', "%{$search}%")
                  ->orWhere('nama_kucing', 'like', "%{$search}%")
                  ->orWhere('ras_kucing', 'like', "%{$search}%");
            });
        }

        return response()->json($query->orderBy('created_at', 'desc')->get());
    }

    public function store(Request $request)
    {
        if ($request->has('owner_name')) {
            $request->merge(['nama_pemilik' => $request->owner_name]);
        }
        if ($request->has('owner_phone')) {
            $request->merge(['telepon_pemilik' => $request->owner_phone]);
        }
        if ($request->has('cat_name')) {
            $request->merge(['nama_kucing' => $request->cat_name]);
        }
        if ($request->has('cat_breed')) {
            $request->merge(['ras_kucing' => $request->cat_breed]);
        }
        if ($request->has('booking_type')) {
            $request->merge(['jenis_pemesanan' => $request->booking_type]);
        }
        if ($request->has('product_id')) {
            $request->merge(['id_produk' => $request->product_id]);
        }
        if ($request->has('price')) {
            $request->merge(['harga' => $request->price]);
        }
        if ($request->has('start_date')) {
            $request->merge(['tanggal_mulai' => $request->start_date]);
        }
        if ($request->has('end_date')) {
            $request->merge(['tanggal_selesai' => $request->end_date]);
        }
        if ($request->has('branch_id')) {
            $request->merge(['id_cabang' => $request->branch_id]);
        }
        if ($request->has('status')) {
            $statusMap = [
                'pending' => 'menunggu',
                'ongoing' => 'berlangsung',
                'completed' => 'selesai',
                'cancelled' => 'dibatalkan',
            ];
            $incomingStatus = $request->status;
            if (isset($statusMap[$incomingStatus])) {
                $request->merge(['status' => $statusMap[$incomingStatus]]);
            }
        }

        $request->validate([
            'nama_pemilik' => 'required|string',
            'telepon_pemilik' => 'required|string',
            'nama_kucing' => 'required|string',
            'ras_kucing' => 'required|string',
            'jenis_pemesanan' => 'required|string|in:grooming,pethotel',
            'id_produk' => 'required|exists:produk,id',
            'harga' => 'required|numeric',
            'tanggal_mulai' => 'required',
            'tanggal_selesai' => 'nullable',
            'id_cabang' => 'required|exists:cabang,id',
        ]);

        $pemesanan = CatBooking::create([
            'nama_pemilik' => $request->nama_pemilik,
            'telepon_pemilik' => $request->telepon_pemilik,
            'nama_kucing' => $request->nama_kucing,
            'ras_kucing' => $request->ras_kucing,
            'jenis_pemesanan' => $request->jenis_pemesanan,
            'id_produk' => $request->id_produk,
            'harga' => $request->harga,
            'tanggal_mulai' => $request->tanggal_mulai,
            'tanggal_selesai' => $request->tanggal_selesai,
            'status' => 'menunggu',
            'id_cabang' => $request->id_cabang,
        ]);

        return response()->json($pemesanan->load('produk'), 201);
    }

    public function update(Request $request, $id)
    {
        $pemesanan = CatBooking::findOrFail($id);

        if ($request->has('owner_name')) {
            $request->merge(['nama_pemilik' => $request->owner_name]);
        }
        if ($request->has('owner_phone')) {
            $request->merge(['telepon_pemilik' => $request->owner_phone]);
        }
        if ($request->has('cat_name')) {
            $request->merge(['nama_kucing' => $request->cat_name]);
        }
        if ($request->has('cat_breed')) {
            $request->merge(['ras_kucing' => $request->cat_breed]);
        }
        if ($request->has('booking_type')) {
            $request->merge(['jenis_pemesanan' => $request->booking_type]);
        }
        if ($request->has('product_id')) {
            $request->merge(['id_produk' => $request->product_id]);
        }
        if ($request->has('price')) {
            $request->merge(['harga' => $request->price]);
        }
        if ($request->has('start_date')) {
            $request->merge(['tanggal_mulai' => $request->start_date]);
        }
        if ($request->has('end_date')) {
            $request->merge(['tanggal_selesai' => $request->end_date]);
        }
        if ($request->has('branch_id')) {
            $request->merge(['id_cabang' => $request->branch_id]);
        }
        if ($request->has('status')) {
            $statusMap = [
                'pending' => 'menunggu',
                'ongoing' => 'berlangsung',
                'completed' => 'selesai',
                'cancelled' => 'dibatalkan',
            ];
            $incomingStatus = $request->status;
            if (isset($statusMap[$incomingStatus])) {
                $request->merge(['status' => $statusMap[$incomingStatus]]);
            }
        }

        $request->validate([
            'nama_pemilik' => 'string',
            'telepon_pemilik' => 'string',
            'nama_kucing' => 'string',
            'ras_kucing' => 'string',
            'jenis_pemesanan' => 'string|in:grooming,pethotel',
            'id_produk' => 'exists:produk,id',
            'harga' => 'numeric',
            'status' => 'string|in:menunggu,berlangsung,selesai,dibatalkan',
            'id_transaksi' => 'nullable|exists:transaksi,id',
        ]);

        $pemesanan->update($request->only([
            'nama_pemilik', 'telepon_pemilik', 'nama_kucing', 'ras_kucing',
            'jenis_pemesanan', 'id_produk', 'harga', 'tanggal_mulai', 'tanggal_selesai',
            'status', 'id_transaksi',
        ]));

        return response()->json($pemesanan->load('produk'));
    }

    public function destroy($id)
    {
        $pemesanan = CatBooking::findOrFail($id);
        $pemesanan->delete();

        return response()->json(['message' => 'Pemesanan berhasil dihapus']);
    }
}
