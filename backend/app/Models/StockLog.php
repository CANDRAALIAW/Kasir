<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StockLog extends Model
{
    // Nama tabel database dalam Bahasa Indonesia
    protected $table = 'log_stok';

    protected $fillable = ['id_produk', 'id_pengguna', 'jenis', 'kuantitas', 'catatan'];

    public function produk()
    {
        return $this->belongsTo(Product::class, 'id_produk');
    }

    // Alias untuk kompatibilitas
    public function product()
    {
        return $this->belongsTo(Product::class, 'id_produk');
    }

    public function pengguna()
    {
        return $this->belongsTo(User::class, 'id_pengguna');
    }

    // Alias untuk kompatibilitas
    public function user()
    {
        return $this->belongsTo(User::class, 'id_pengguna');
    }
}
