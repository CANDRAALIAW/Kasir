<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Transaction extends Model
{
    // Nama tabel database dalam Bahasa Indonesia
    protected $table = 'transaksi';

    protected $fillable = [
        'nomor_invoice', 'id_pengguna', 'id_cabang', 'total', 'status',
        'metode_pembayaran', 'jumlah_bayar', 'jumlah_kembalian'
    ];

    public function pengguna()
    {
        return $this->belongsTo(User::class, 'id_pengguna');
    }

    // Alias untuk kompatibilitas
    public function user()
    {
        return $this->belongsTo(User::class, 'id_pengguna');
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

    public function detailTransaksi()
    {
        return $this->hasMany(TransactionDetail::class, 'id_transaksi');
    }

    // Alias untuk kompatibilitas
    public function details()
    {
        return $this->hasMany(TransactionDetail::class, 'id_transaksi');
    }
}
