<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    /**
     * Ubah resource menjadi array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'nama' => $this->nama,
            'deskripsi' => $this->deskripsi,
            'harga' => (float) $this->harga,
            'stok' => (int) $this->stok,
            'stok_minimum' => (int) $this->stok_minimum,
            'id_cabang' => $this->id_cabang,
            'jenis' => $this->jenis,
            'path_gambar' => $this->path_gambar,
            'url_gambar' => $this->path_gambar ? asset('storage/' . $this->path_gambar) : null,
            'dibuat_pada' => $this->created_at,
            'diperbarui_pada' => $this->updated_at,
        ];
    }
}
