<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stock_logs', function (Blueprint $box) {
            $box->id();
            $box->foreignId('product_id')->constrained()->onDelete('cascade');
            $box->foreignId('user_id')->constrained();
            $box->enum('type', ['in', 'out']); // in = restock, out = adjustment/waste
            $box->integer('quantity');
            $box->string('note')->nullable();
            $box->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_logs');
    }
};
