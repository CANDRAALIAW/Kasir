<?php

namespace App\Exports;

use App\Models\Transaction;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;

class TransactionsExport implements FromCollection, WithHeadings, WithMapping
{
    protected $idCabang;
    protected $tanggalMulai;
    protected $tanggalSelesai;

    public function __construct($idCabang = null, $tanggalMulai = null, $tanggalSelesai = null)
    {
        $this->idCabang = $idCabang;
        $this->tanggalMulai = $tanggalMulai;
        $this->tanggalSelesai = $tanggalSelesai;
    }

    public function collection()
    {
        $query = Transaction::with(['pengguna', 'cabang']);

        if ($this->idCabang) {
            $query->where('id_cabang', $this->idCabang);
        }

        if ($this->tanggalMulai && $this->tanggalSelesai) {
            $query->whereBetween('created_at', [$this->tanggalMulai, $this->tanggalSelesai]);
        }

        return $query->get();
    }

    public function headings(): array
    {
        return [
            'ID Transaksi',
            'Nomor Invoice',
            'Nama Kasir',
            'Cabang',
            'Total (IDR)',
            'Status',
            'Hari',
            'Tanggal',
            'Jam'
        ];
    }

    public function map($transaksi): array
    {
        return [
            $transaksi->id,
            $transaksi->nomor_invoice,
            $transaksi->pengguna->nama ?? '-',
            $transaksi->cabang->nama ?? '-',
            $transaksi->total,
            $transaksi->status,
            $transaksi->created_at->translatedFormat('l'),
            $transaksi->created_at->format('d F Y'),
            $transaksi->created_at->format('H:i:s'),
        ];
    }
}
