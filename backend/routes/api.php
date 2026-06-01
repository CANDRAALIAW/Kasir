<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\TransactionController;
use App\Http\Controllers\ReportController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Public routes
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:100,1');

// Protected routes (all authenticated users)
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    // Branches (read-only, all roles)
    Route::get('/branches', function () {
        return \App\Models\Branch::orderBy('nama')->get(['id', 'nama']);
    });

    // Products - read: all roles, write: admin only
    Route::get('/products', [ProductController::class, 'index']);
    Route::middleware('admin')->group(function () {
        Route::post('/products', [ProductController::class, 'store']);
        Route::put('/products/{id}', [ProductController::class, 'update']);
        Route::delete('/products/{id}', [ProductController::class, 'destroy']);
    });

    // Transactions
    Route::post('/transactions', [TransactionController::class, 'store']);
    Route::get('/transactions', [TransactionController::class, 'index']);

    // Reports - accessible by all authenticated users (filtered by branch)
    Route::get('/reports/income', [ReportController::class, 'incomeStats']);
    Route::get('/reports/daily', [ReportController::class, 'dailyReport']);
    Route::get('/reports/branches', [ReportController::class, 'branchComparison']);
    
    // Export - admin only or with token query param for browser download
    Route::get('/reports/export', [ReportController::class, 'exportExcel']);

    // Inventory - admin only for restock, all for history
    Route::middleware('admin')->post('/inventory/restock', [\App\Http\Controllers\InventoryController::class, 'restock']);
    Route::get('/inventory/history', [\App\Http\Controllers\InventoryController::class, 'history']);

    // Activity Logs - admin only
    Route::get('/activity-logs', function (Request $request) {
        if ($request->user()->role !== 'admin') {
            return response()->json(['message' => 'Unauthorized'], 403);
        }
        return \App\Models\ActivityLog::with('user')->latest()->paginate(50);
    });

    // User Management - admin only
    Route::apiResource('/users', \App\Http\Controllers\UserController::class)->middleware('admin');

    // Cat Bookings - all authenticated
    Route::get('/bookings', [\App\Http\Controllers\CatBookingController::class, 'index']);
    Route::post('/bookings', [\App\Http\Controllers\CatBookingController::class, 'store']);
    Route::put('/bookings/{id}', [\App\Http\Controllers\CatBookingController::class, 'update']);
    Route::delete('/bookings/{id}', [\App\Http\Controllers\CatBookingController::class, 'destroy']);
});
