<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TransactionDetail extends Model
{
    // Nama tabel database dalam Bahasa Indonesia
    protected $table = 'detail_transaksi';

    protected $fillable = ['id_transaksi', 'id_produk', 'harga_satuan', 'jumlah', 'subtotal'];

    public function transaksi()
    {
        return $this->belongsTo(Transaction::class, 'id_transaksi');
    }

    // Alias untuk kompatibilitas
    public function transaction()
    {
        return $this->belongsTo(Transaction::class, 'id_transaksi');
    }

    public function produk()
    {
        return $this->belongsTo(Product::class, 'id_produk');
    }

    // Alias untuk kompatibilitas
    public function product()
    {
        return $this->belongsTo(Product::class, 'id_produk');
    }
}
