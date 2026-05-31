<?php

namespace App\Exports;

use App\Models\Transaction;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;

class TransactionsExport implements FromCollection, WithHeadings, WithMapping
{
    protected $branchId;
    protected $startDate;
    protected $endDate;

    public function __construct($branchId = null, $startDate = null, $endDate = null)
    {
        $this->branchId = $branchId;
        $this->startDate = $startDate;
        $this->endDate = $endDate;
    }

    public function collection()
    {
        $query = Transaction::with(['user', 'branch']);

        if ($this->branchId) {
            $query->where('branch_id', $this->branchId);
        }

        if ($this->startDate && $this->endDate) {
            $query->whereBetween('created_at', [$this->startDate, $this->endDate]);
        }

        return $query->get();
    }

    public function headings(): array
    {
        return [
            'ID Transaksi',
            'No Invoice',
            'Nama Kasir',
            'Cabang',
            'Total (IDR)',
            'Status',
            'Hari',
            'Tanggal',
            'Jam'
        ];
    }

    public function map($transaction): array
    {
        return [
            $transaction->id,
            $transaction->invoice_number,
            $transaction->user->name,
            $transaction->branch->name,
            $transaction->total,
            $transaction->status,
            $transaction->created_at->translatedFormat('l'),
            $transaction->created_at->format('d F Y'),
            $transaction->created_at->format('H:i:s'),
        ];
    }
}
