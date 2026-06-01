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
        Schema::table('produk', function (Blueprint $table) {
            $table->integer('stok_minimum')->default(5)->after('stok');
        });

        Schema::table('transaksi', function (Blueprint $table) {
            $table->string('metode_pembayaran')->default('tunai')->after('total');
            $table->decimal('jumlah_bayar', 15, 2)->default(0)->after('metode_pembayaran');
            $table->decimal('jumlah_kembalian', 15, 2)->default(0)->after('jumlah_bayar');
        });
    }

    /**
     * Balikkan migrasi.
     */
    public function down(): void
    {
        Schema::table('produk', function (Blueprint $table) {
            $table->dropColumn('stok_minimum');
        });

        Schema::table('transaksi', function (Blueprint $table) {
            $table->dropColumn(['metode_pembayaran', 'jumlah_bayar', 'jumlah_kembalian']);
        });
    }
};
