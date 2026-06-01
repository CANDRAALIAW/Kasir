<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Exports\TransactionsExport;
use App\Http\Resources\TransactionResource;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class ReportController extends Controller
{
    public function incomeStats(Request $request)
    {
        $tipe = $request->query('type', 'harian'); // harian, bulanan, tahunan
        $idCabang = $request->query('branch_id');
        $tanggal = $request->query('date', Carbon::today()->toDateString());
        $bulan = $request->query('month', Carbon::today()->format('Y-m'));
        $tahun = $request->query('year', Carbon::today()->format('Y'));

        $query = Transaction::query();
        if ($idCabang) {
            $query->where('id_cabang', $idCabang);
        }

        // Dukungan parameter tipe lama
        if ($tipe === 'daily') $tipe = 'harian';
        if ($tipe === 'monthly') $tipe = 'bulanan';
        if ($tipe === 'yearly') $tipe = 'tahunan';

        switch ($tipe) {
            case 'harian':
                // Rincian per jam dari tanggal yang dipilih
                $statistik = $query->select(
                    DB::raw("strftime('%H:00', created_at) as label"),
                    DB::raw('SUM(total) as value')
                )
                ->whereDate('created_at', $tanggal)
                ->groupBy('label')
                ->orderBy('label')
                ->get();
                break;

            case 'bulanan':
                // Rincian per hari dari bulan yang dipilih (format YYYY-MM)
                $statistik = $query->select(
                    DB::raw("strftime('%d', created_at) as label"),
                    DB::raw('SUM(total) as value')
                )
                ->whereYear('created_at', substr($bulan, 0, 4))
                ->whereMonth('created_at', substr($bulan, 5, 2))
                ->groupBy('label')
                ->orderBy('label')
                ->get();
                break;

            case 'tahunan':
                // Rincian per bulan dari tahun yang dipilih (format YYYY)
                $statistik = $query->select(
                    DB::raw("strftime('%m', created_at) as label"),
                    DB::raw('SUM(total) as value')
                )
                ->whereYear('created_at', $tahun)
                ->groupBy('label')
                ->orderBy('label')
                ->get();
                break;

            default:
                $statistik = [];
                break;
        }

        return response()->json([
            'status' => 'berhasil',
            'tipe' => $tipe,
            'tanggal' => $tanggal,
            'bulan' => $bulan,
            'tahun' => $tahun,
            'data' => $statistik
        ]);
    }

    public function dailyReport(Request $request)
    {
        $tipe = $request->query('type', 'harian'); // harian, bulanan, tahunan
        $idCabang = $request->query('branch_id');
        $tanggal = $request->query('date', Carbon::today()->toDateString());
        $bulan = $request->query('month', Carbon::today()->format('Y-m'));
        $tahun = $request->query('year', Carbon::today()->format('Y'));
        $cari = $request->query('search');
        $metodePembayaran = $request->query('payment_method');

        // Dukungan tipe lama
        if ($tipe === 'daily') $tipe = 'harian';
        if ($tipe === 'monthly') $tipe = 'bulanan';
        if ($tipe === 'yearly') $tipe = 'tahunan';

        $query = Transaction::query();
        if ($idCabang) {
            $query->where('id_cabang', $idCabang);
        }
        if ($cari) {
            $query->where(function($q) use ($cari) {
                $q->where('nomor_invoice', 'like', "%{$cari}%")
                  ->orWhereHas('pengguna', function($qu) use ($cari) {
                      $qu->where('nama', 'like', "%{$cari}%");
                  });
            });
        }
        if ($metodePembayaran && $metodePembayaran !== 'semua') {
            $query->where('metode_pembayaran', strtolower($metodePembayaran));
        }

        if ($tipe === 'harian') {
            $query->whereDate('created_at', $tanggal);
        } elseif ($tipe === 'bulanan') {
            $query->whereYear('created_at', substr($bulan, 0, 4))
                  ->whereMonth('created_at', substr($bulan, 5, 2));
        } elseif ($tipe === 'tahunan') {
            $query->whereYear('created_at', $tahun);
        }

        $transaksiList = $query->with(['pengguna', 'detailTransaksi.produk', 'cabang'])->latest()->get();

        $totalPendapatan = 0;
        $jumlahTransaksi = count($transaksiList);
        $totalTunai = 0;
        $totalQris = 0;
        $totalTransfer = 0;

        // Rekap produk terjual
        $ringkasanTerjual = [];

        foreach ($transaksiList as $tx) {
            $totalPendapatan += $tx->total;
            if ($tx->metode_pembayaran === 'tunai') $totalTunai += $tx->total;
            elseif ($tx->metode_pembayaran === 'qris') $totalQris += $tx->total;
            elseif ($tx->metode_pembayaran === 'transfer') $totalTransfer += $tx->total;

            foreach ($tx->detailTransaksi as $detail) {
                if (!$detail->produk) continue;
                $pId = $detail->id_produk;
                if (!isset($ringkasanTerjual[$pId])) {
                    $ringkasanTerjual[$pId] = [
                        'id_produk' => $pId,
                        'nama' => $detail->produk->nama,
                        'jumlah' => 0,
                        'pendapatan' => 0,
                        'jenis' => $detail->produk->jenis ?? 'produk'
                    ];
                }
                $ringkasanTerjual[$pId]['jumlah'] += $detail->jumlah;
                $ringkasanTerjual[$pId]['pendapatan'] += $detail->subtotal;
            }
        }

        // Kueri produk masuk (log_stok masuk)
        $queryLogMasuk = \App\Models\StockLog::with(['produk', 'pengguna'])->where('jenis', 'masuk');
        if ($tipe === 'harian') {
            $queryLogMasuk->whereDate('created_at', $tanggal);
        } elseif ($tipe === 'bulanan') {
            $queryLogMasuk->whereYear('created_at', substr($bulan, 0, 4))
                          ->whereMonth('created_at', substr($bulan, 5, 2));
        } elseif ($tipe === 'tahunan') {
            $queryLogMasuk->whereYear('created_at', $tahun);
        }
        if ($idCabang) {
            $queryLogMasuk->whereHas('produk', function($q) use ($idCabang) {
                $q->where('id_cabang', $idCabang);
            });
        }
        $logMasuk = $queryLogMasuk->latest()->get();

        // Rekap produk masuk
        $ringkasanMasuk = [];
        foreach ($logMasuk as $log) {
            if (!$log->produk) continue;
            $pId = $log->id_produk;
            if (!isset($ringkasanMasuk[$pId])) {
                $ringkasanMasuk[$pId] = [
                    'id_produk' => $pId,
                    'nama' => $log->produk->nama,
                    'kuantitas' => 0,
                ];
            }
            $ringkasanMasuk[$pId]['kuantitas'] += $log->kuantitas;
        }

        return response()->json([
            'status' => 'berhasil',
            'tipe' => $tipe,
            'tanggal' => $tanggal,
            'bulan' => $bulan,
            'tahun' => $tahun,
            'total_pendapatan' => (float) $totalPendapatan,
            'jumlah_transaksi' => (int) $jumlahTransaksi,
            'total_tunai' => (float) $totalTunai,
            'total_qris' => (float) $totalQris,
            'total_transfer' => (float) $totalTransfer,
            'ringkasan_terjual' => array_values($ringkasanTerjual),
            'ringkasan_masuk' => array_values($ringkasanMasuk),
            'log_masuk' => $logMasuk,
            'transaksi' => TransactionResource::collection($transaksiList)
        ]);
    }

    public function branchComparison(Request $request)
    {
        $statistik = Transaction::select(
            'cabang.nama as nama_cabang',
            DB::raw('SUM(total) as pendapatan'),
            DB::raw('COUNT(*) as total_pesanan')
        )
        ->join('cabang', 'transaksi.id_cabang', '=', 'cabang.id')
        ->where('transaksi.created_at', '>=', Carbon::now()->subDays(30))
        ->groupBy('cabang.nama')
        ->get();

        return response()->json([
            'status' => 'berhasil',
            'data' => $statistik
        ]);
    }

    public function exportExcel(Request $request)
    {
        $idCabang = $request->query('branch_id');
        $tanggalMulai = $request->query('start_date');
        $tanggalSelesai = $request->query('end_date');
        $namaFile = 'Laporan_Penjualan_' . ($idCabang ? 'Cabang_'.$idCabang.'_' : '') . now()->format('Y-m-d_H-i-s') . '.xlsx';

        return Excel::download(new TransactionsExport($idCabang, $tanggalMulai, $tanggalSelesai), $namaFile);
    }
}
