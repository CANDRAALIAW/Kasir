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
        if ($request->has('payment_method')) {
            $request->merge(['metode_pembayaran' => $request->payment_method]);
        }
        if ($request->has('payment_amount')) {
            $request->merge(['jumlah_bayar' => $request->payment_amount]);
        }
        if ($request->has('change_amount')) {
            $request->merge(['jumlah_kembalian' => $request->change_amount]);
        }
        if ($request->has('booking_id')) {
            $request->merge(['id_pemesanan' => $request->booking_id]);
        }
        if ($request->has('items')) {
            $items = $request->items;
            foreach ($items as &$item) {
                if (isset($item['product_id'])) {
                    $item['id_produk'] = $item['product_id'];
                }
                if (isset($item['qty'])) {
                    $item['jumlah'] = $item['qty'];
                }
            }
            $request->merge(['items' => $items]);
        }

        $request->validate([
            'items' => 'required|array',
            'items.*.id_produk' => 'required|exists:produk,id',
            'items.*.jumlah' => 'required|integer|min:1',
            'total' => 'required|numeric',
            'metode_pembayaran' => 'string|in:tunai,qris,transfer',
            'jumlah_bayar' => 'numeric',
            'jumlah_kembalian' => 'numeric',
            'id_pemesanan' => 'nullable|exists:pemesanan_kucing,id',
        ]);

        $pengguna = $request->user();
        
        if (!$pengguna->id_cabang) {
            return response()->json(['message' => 'Pengguna tidak ditugaskan ke cabang manapun'], 403);
        }

        return DB::transaction(function () use ($request, $pengguna) {
            $nomorInvoice = 'INV-' . strtoupper(Str::random(10));

            $transaksi = Transaction::create([
                'nomor_invoice' => $nomorInvoice,
                'id_pengguna' => $pengguna->id,
                'id_cabang' => $pengguna->id_cabang,
                'total' => $request->total,
                'status' => 'selesai',
                'metode_pembayaran' => $request->metode_pembayaran ?? 'tunai',
                'jumlah_bayar' => $request->jumlah_bayar ?? 0,
                'jumlah_kembalian' => $request->jumlah_kembalian ?? 0,
            ]);

            foreach ($request->items as $item) {
                $produk = Product::lockForUpdate()->findOrFail($item['id_produk']);
                
                $hargaSatuan = $produk->harga;
                $subtotal = $hargaSatuan * $item['jumlah'];

                TransactionDetail::create([
                    'id_transaksi' => $transaksi->id,
                    'id_produk' => $produk->id,
                    'harga_satuan' => $hargaSatuan,
                    'jumlah' => $item['jumlah'],
                    'subtotal' => $subtotal,
                ]);

                // Layanan tidak memiliki manajemen stok
                if (($produk->jenis ?? 'produk') !== 'layanan') {
                    if ($produk->stok < $item['jumlah']) {
                        throw new \Exception("Stok tidak mencukupi untuk produk: {$produk->nama}");
                    }

                    // Kurangi stok
                    $produk->decrement('stok', $item['jumlah']);

                    // Catat pergerakan stok
                    \App\Models\StockLog::create([
                        'id_produk' => $produk->id,
                        'id_pengguna' => $pengguna->id,
                        'jenis' => 'keluar',
                        'kuantitas' => $item['jumlah'],
                        'catatan' => "Terjual melalui $nomorInvoice",
                    ]);

                    // Cek apakah stok sekarang sudah kritis
                    $produkTerbaru = $produk->fresh();
                    if ($produkTerbaru->stok <= $produkTerbaru->stok_minimum) {
                        // Buat log peringatan stok kritis (simulasi WhatsApp Alert)
                        \App\Models\ActivityLog::create([
                            'id_pengguna' => $pengguna->id,
                            'aksi' => 'Peringatan Stok Kritis WA',
                            'deskripsi' => "[PERINGATAN WA] Dikirim ke Admin: Stok produk '{$produk->nama}' kritis! Sisa stok saat ini: {$produkTerbaru->stok} (Batas minimum: {$produkTerbaru->stok_minimum}).",
                            'properti' => [
                                'id_produk' => $produk->id,
                                'nama_produk' => $produk->nama,
                                'sisa_stok' => $produkTerbaru->stok,
                                'stok_minimum' => $produkTerbaru->stok_minimum,
                                'penerima' => 'Admin Petshop (081234567890)',
                            ],
                            'alamat_ip' => $request->ip(),
                        ]);
                    }
                }
            }

            // Perbarui pemesanan kucing yang terhubung jika ada
            if ($request->has('id_pemesanan')) {
                $pemesanan = \App\Models\CatBooking::find($request->id_pemesanan);
                if ($pemesanan) {
                    $pemesanan->update([
                        'status' => 'selesai',
                        'id_transaksi' => $transaksi->id,
                    ]);
                }
            }

            \App\Models\ActivityLog::create([
                'id_pengguna' => $pengguna->id,
                'aksi' => 'Checkout',
                'deskripsi' => "Kasir melakukan transaksi {$nomorInvoice} sebesar Rp " . number_format($request->total, 0, ',', '.'),
                'properti' => [
                    'id_transaksi' => $transaksi->id,
                    'nomor_invoice' => $nomorInvoice,
                    'total' => $request->total,
                ],
                'alamat_ip' => $request->ip(),
            ]);

            return response()->json([
                'message' => 'Transaksi berhasil diselesaikan',
                'transaksi' => $transaksi->load('detailTransaksi.produk')
            ], 201);
        });
    }

    public function index(Request $request)
    {
        $idCabang = $request->query('branch_id');
        $query = Transaction::with(['pengguna', 'detailTransaksi.produk', 'cabang']);

        if ($idCabang) {
            $query->where('id_cabang', $idCabang);
        }

        if ($request->has('search') && $request->search != '') {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('nomor_invoice', 'like', "%{$search}%")
                  ->orWhereHas('pengguna', function($qu) use ($search) {
                      $qu->where('nama', 'like', "%{$search}%");
                  });
            });
        }

        if ($request->has('metode_pembayaran') && $request->metode_pembayaran != '' && $request->metode_pembayaran != 'semua') {
            $query->where('metode_pembayaran', strtolower($request->metode_pembayaran));
        }

        if ($request->has('tanggal_mulai') && $request->tanggal_mulai != '') {
            $query->whereDate('created_at', '>=', $request->tanggal_mulai);
        }

        if ($request->has('tanggal_selesai') && $request->tanggal_selesai != '') {
            $query->whereDate('created_at', '<=', $request->tanggal_selesai);
        }

        // Dukungan parameter lama untuk kompatibilitas frontend
        if ($request->has('payment_method') && $request->payment_method != '' && $request->payment_method != 'semua') {
            $query->where('metode_pembayaran', strtolower($request->payment_method));
        }
        if ($request->has('date_start') && $request->date_start != '') {
            $query->whereDate('created_at', '>=', $request->date_start);
        }
        if ($request->has('date_end') && $request->date_end != '') {
            $query->whereDate('created_at', '<=', $request->date_end);
        }

        $transaksi = $query->orderBy('created_at', 'desc')->get();
        return \App\Http\Resources\TransactionResource::collection($transaksi);
    }
}
