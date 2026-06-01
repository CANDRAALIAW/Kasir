<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    protected $table = 'pengguna';

    protected $fillable = ['nama', 'email', 'kata_sandi', 'peran', 'id_cabang'];
    protected $hidden = ['kata_sandi', 'remember_token'];

    protected $appends = ['name', 'role', 'branch_id', 'branch'];

    public function getNameAttribute()
    {
        return $this->nama;
    }

    public function getRoleAttribute()
    {
        return $this->peran;
    }

    public function getBranchIdAttribute()
    {
        return $this->id_cabang;
    }

    public function getBranchAttribute()
    {
        return $this->relationLoaded('cabang') ? $this->cabang : null;
    }

    // Pemetaan kolom untuk autentikasi Laravel
    public function getAuthPassword()
    {
        return $this->kata_sandi;
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

    /**
     * Dapatkan atribut yang harus di-cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_terverifikasi_pada' => 'datetime',
            // 'kata_sandi' => 'hashed', // Dihapus karena seeder sudah pakai Hash::make() manual
        ];
    }
}
