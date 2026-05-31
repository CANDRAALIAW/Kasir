<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Add soft delete to products
        Schema::table('products', function (Blueprint $table) {
            $table->softDeletes();
        });

        // Add indexes to activity_logs for performance
        Schema::table('activity_logs', function (Blueprint $table) {
            $table->index('user_id');
            $table->index('action');
            $table->index('created_at');
        });

        // Add indexes to transactions for report performance
        Schema::table('transactions', function (Blueprint $table) {
            $table->index(['branch_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropSoftDeletes();
        });

        Schema::table('activity_logs', function (Blueprint $table) {
            $table->dropIndex(['user_id']);
            $table->dropIndex(['action']);
            $table->dropIndex(['created_at']);
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->dropIndex(['branch_id', 'created_at']);
        });
    }
};
