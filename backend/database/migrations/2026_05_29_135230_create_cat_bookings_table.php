<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Jalankan migrasi.
     */
    public function up(): void
    {
        Schema::create('pemesanan_kucing', function (Blueprint $table) {
            $table->id();
            $table->string('nama_pemilik');
            $table->string('telepon_pemilik');
            $table->string('nama_kucing');
            $table->string('ras_kucing');
            $table->string('jenis_pemesanan'); // 'grooming' atau 'pethotel'
            $table->unsignedBigInteger('id_produk');
            $table->foreign('id_produk')->references('id')->on('produk')->onDelete('cascade'); // paket layanan
            $table->decimal('harga', 15, 2);
            $table->dateTime('tanggal_mulai');
            $table->dateTime('tanggal_selesai')->nullable();
            $table->string('status')->default('menunggu'); // menunggu, berlangsung, selesai, dibatalkan
            $table->unsignedBigInteger('id_cabang');
            $table->foreign('id_cabang')->references('id')->on('cabang')->onDelete('cascade');
            $table->unsignedBigInteger('id_transaksi')->nullable();
            $table->foreign('id_transaksi')->references('id')->on('transaksi')->onDelete('set null');
            $table->timestamps();
        });
    }

    /**
     * Balikkan migrasi.
     */
    public function down(): void
    {
        Schema::dropIfExists('pemesanan_kucing');
    }
};
