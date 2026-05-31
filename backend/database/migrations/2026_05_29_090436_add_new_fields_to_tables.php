<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->integer('minimum_stock')->default(5)->after('stock');
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->string('payment_method')->default('tunai')->after('total');
            $table->decimal('payment_amount', 15, 2)->default(0)->after('payment_method');
            $table->decimal('change_amount', 15, 2)->default(0)->after('payment_amount');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn('minimum_stock');
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->dropColumn(['payment_method', 'payment_amount', 'change_amount']);
        });
    }
};

