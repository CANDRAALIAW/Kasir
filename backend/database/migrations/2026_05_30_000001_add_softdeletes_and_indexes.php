<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Tambah soft delete ke produk
        Schema::table('produk', function (Blueprint $table) {
            $table->softDeletes();
        });

        // Tambah indeks ke log_aktivitas untuk performa
        Schema::table('log_aktivitas', function (Blueprint $table) {
            $table->index('id_pengguna');
            $table->index('aksi');
            $table->index('created_at');
        });

        // Tambah indeks ke transaksi untuk performa laporan
        Schema::table('transaksi', function (Blueprint $table) {
            $table->index(['id_cabang', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::table('produk', function (Blueprint $table) {
            $table->dropSoftDeletes();
        });

        Schema::table('log_aktivitas', function (Blueprint $table) {
            $table->dropIndex(['id_pengguna']);
            $table->dropIndex(['aksi']);
            $table->dropIndex(['created_at']);
        });

        Schema::table('transaksi', function (Blueprint $table) {
            $table->dropIndex(['id_cabang', 'created_at']);
        });
    }
};
