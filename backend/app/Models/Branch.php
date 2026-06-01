<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Branch extends Model
{
    // Nama tabel database dalam Bahasa Indonesia
    protected $table = 'cabang';

    protected $fillable = ['nama'];

    protected $appends = ['name'];

    public function getNameAttribute()
    {
        return $this->nama;
    }

    public function pengguna()
    {
        return $this->hasMany(User::class, 'id_cabang');
    }

    // Alias untuk kompatibilitas
    public function users()
    {
        return $this->hasMany(User::class, 'id_cabang');
    }

    public function produk()
    {
        return $this->hasMany(Product::class, 'id_cabang');
    }

    // Alias untuk kompatibilitas
    public function products()
    {
        return $this->hasMany(Product::class, 'id_cabang');
    }

    public function transaksi()
    {
        return $this->hasMany(Transaction::class, 'id_cabang');
    }

    // Alias untuk kompatibilitas
    public function transactions()
    {
        return $this->hasMany(Transaction::class, 'id_cabang');
    }
}
