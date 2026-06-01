<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ActivityLog extends Model
{
    // Nama tabel database dalam Bahasa Indonesia
    protected $table = 'log_aktivitas';

    protected $fillable = ['id_pengguna', 'aksi', 'deskripsi', 'properti', 'alamat_ip'];

    protected $casts = [
        'properti' => 'array'
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
}
