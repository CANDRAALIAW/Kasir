<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class AdminOnly
{
    public function handle(Request $request, Closure $next)
    {
        if (!$request->user() || $request->user()->peran !== 'admin') {
            return response()->json(['message' => 'Tidak diizinkan. Diperlukan akses admin.'], 403);
        }
        return $next($request);
    }
}
