<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CatBooking extends Model
{
    // Nama tabel database dalam Bahasa Indonesia
    protected $table = 'pemesanan_kucing';

    protected $fillable = [
        'nama_pemilik',
        'telepon_pemilik',
        'nama_kucing',
        'ras_kucing',
        'jenis_pemesanan',
        'id_produk',
        'harga',
        'tanggal_mulai',
        'tanggal_selesai',
        'status',
        'id_cabang',
        'id_transaksi',
    ];

    public function produk()
    {
        return $this->belongsTo(Product::class, 'id_produk');
    }

    // Alias untuk kompatibilitas
    public function product()
    {
        return $this->belongsTo(Product::class, 'id_produk');
    }

    public function cabang()
    {
        return $this->belongsTo(Branch::class, 'id_cabang');
    }

    // Alias untuk kompatibilitas
    public function branch()
    {
        return $this->belongsTo(Branch::class, 'id_cabang');
    }

    public function transaksi()
    {
        return $this->belongsTo(Transaction::class, 'id_transaksi');
    }

    // Alias untuk kompatibilitas
    public function transaction()
    {
        return $this->belongsTo(Transaction::class, 'id_transaksi');
    }
}
