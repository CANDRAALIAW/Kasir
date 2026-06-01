<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'nomor_invoice' => $this->nomor_invoice,
            'invoice_number' => $this->nomor_invoice, // Compatibility
            'nama_pengguna' => $this->pengguna->nama ?? 'Tidak Diketahui',
            'user_name' => $this->pengguna->nama ?? 'Tidak Diketahui', // Compatibility
            'nama_cabang' => $this->cabang->nama ?? 'Tidak Diketahui',
            'branch_name' => $this->cabang->nama ?? 'Tidak Diketahui', // Compatibility
            'total' => (float) $this->total,
            'status' => $this->status,
            'metode_pembayaran' => $this->metode_pembayaran,
            'payment_method' => $this->metode_pembayaran, // Compatibility
            'jumlah_bayar' => (float) $this->jumlah_bayar,
            'payment_amount' => (float) $this->jumlah_bayar, // Compatibility
            'jumlah_kembalian' => (float) $this->jumlah_kembalian,
            'change_amount' => (float) $this->jumlah_kembalian, // Compatibility
            'detail' => TransactionDetailResource::collection($this->whenLoaded('detailTransaksi')),
            'details' => TransactionDetailResource::collection($this->whenLoaded('detailTransaksi')), // Compatibility
            'dibuat_pada' => $this->created_at,
            'tanggal_format' => $this->created_at->format('d M Y H:i'),
            'formatted_date' => $this->created_at->format('d M Y H:i'), // Compatibility
        ];
    }
}
