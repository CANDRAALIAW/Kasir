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
        Schema::create('cat_bookings', function (Blueprint $table) {
            $table->id();
            $table->string('owner_name');
            $table->string('owner_phone');
            $table->string('cat_name');
            $table->string('cat_breed');
            $table->string('booking_type'); // 'grooming' or 'pethotel'
            $table->foreignId('product_id')->constrained()->onDelete('cascade'); // service package
            $table->decimal('price', 15, 2);
            $table->dateTime('start_date');
            $table->dateTime('end_date')->nullable();
            $table->string('status')->default('pending'); // pending, ongoing, completed, cancelled
            $table->foreignId('branch_id')->constrained()->onDelete('cascade');
            $table->foreignId('transaction_id')->nullable()->constrained()->onDelete('set null');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('cat_bookings');
    }
};
