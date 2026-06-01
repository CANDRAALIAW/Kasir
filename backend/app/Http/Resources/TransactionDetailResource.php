<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransactionDetailResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'id_produk' => $this->id_produk,
            'product_id' => $this->id_produk, // Compatibility
            'nama_produk' => $this->produk->nama ?? 'Produk Dihapus',
            'product_name' => $this->produk->nama ?? 'Produk Dihapus', // Compatibility
            'jumlah' => (int) $this->jumlah,
            'qty' => (int) $this->jumlah, // Compatibility
            'harga_satuan' => (float) $this->harga_satuan,
            'price' => (float) $this->harga_satuan, // Compatibility
            'subtotal' => (float) $this->subtotal,
        ];
    }
}
