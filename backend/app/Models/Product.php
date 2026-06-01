<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Product extends Model
{
    use SoftDeletes;

    // Nama tabel database dalam Bahasa Indonesia
    protected $table = 'produk';

    protected $fillable = ['nama', 'deskripsi', 'harga', 'stok', 'path_gambar', 'id_cabang', 'stok_minimum', 'jenis'];

    public function cabang()
    {
        return $this->belongsTo(Branch::class, 'id_cabang');
    }

    // Alias untuk kompatibilitas
    public function branch()
    {
        return $this->belongsTo(Branch::class, 'id_cabang');
    }

    public function logStok()
    {
        return $this->hasMany(StockLog::class, 'id_produk');
    }

    // Alias untuk kompatibilitas
    public function stockLogs()
    {
        return $this->hasMany(StockLog::class, 'id_produk');
    }
}
