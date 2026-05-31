<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('activity_logs', function (Blueprint $box) {
            $box->id();
            $box->foreignId('user_id')->constrained();
            $box->string('action'); // e.g., 'Update Price', 'Delete Product'
            $box->string('description');
            $box->json('properties')->nullable(); // stored old vs new values
            $box->string('ip_address')->nullable();
            $box->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activity_logs');
    }
};
