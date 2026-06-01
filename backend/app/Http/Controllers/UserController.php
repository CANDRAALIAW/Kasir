<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class UserController extends Controller
{
    public function index(Request $request)
    {
        // Hanya admin yang dapat melihat/mengelola pengguna
        if ($request->user()->peran !== 'admin') {
            return response()->json(['message' => 'Tidak diizinkan'], 403);
        }

        $users = User::where('peran', 'kasir')->with('cabang')->orderBy('nama', 'asc')->get();
        return response()->json($users);
    }

    public function store(Request $request)
    {
        if ($request->user()->peran !== 'admin') {
            return response()->json(['message' => 'Tidak diizinkan'], 403);
        }

        if ($request->has('name')) {
            $request->merge(['nama' => $request->name]);
        }
        if ($request->has('branch_id')) {
            $request->merge(['id_cabang' => $request->branch_id]);
        }
        if ($request->has('password')) {
            $request->merge(['kata_sandi' => $request->password]);
        }

        $request->validate([
            'nama' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:pengguna',
            'kata_sandi' => 'required|string|min:6',
            'id_cabang' => 'required|exists:cabang,id',
        ]);

        $user = User::create([
            'nama' => $request->nama,
            'email' => $request->email,
            'kata_sandi' => Hash::make($request->kata_sandi),
            'peran' => 'kasir',
            'id_cabang' => $request->id_cabang,
        ]);

        return response()->json($user, 201);
    }

    public function update(Request $request, $id)
    {
        if ($request->user()->peran !== 'admin') {
            return response()->json(['message' => 'Tidak diizinkan'], 403);
        }

        $user = User::where('peran', 'kasir')->findOrFail($id);

        if ($request->has('name')) {
            $request->merge(['nama' => $request->name]);
        }
        if ($request->has('branch_id')) {
            $request->merge(['id_cabang' => $request->branch_id]);
        }
        if ($request->has('password')) {
            $request->merge(['kata_sandi' => $request->password]);
        }

        $request->validate([
            'nama' => 'string|max:255',
            'email' => 'string|email|max:255|unique:pengguna,email,' . $user->id,
            'kata_sandi' => 'nullable|string|min:6',
            'id_cabang' => 'exists:cabang,id',
        ]);

        $data = $request->only(['nama', 'email', 'id_cabang']);
        if ($request->filled('kata_sandi')) {
            $data['kata_sandi'] = Hash::make($request->kata_sandi);
        }

        $user->update($data);

        return response()->json($user);
    }

    public function destroy(Request $request, $id)
    {
        if ($request->user()->peran !== 'admin') {
            return response()->json(['message' => 'Tidak diizinkan'], 403);
        }

        $user = User::where('peran', 'kasir')->findOrFail($id);
        $user->delete();

        return response()->json(['message' => 'Pengguna berhasil dihapus']);
    }
}
