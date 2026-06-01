<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Isi database aplikasi.
     */
    public function run(): void
    {
        // 1. Buat Cabang
        $cabang = [];
        for ($i = 1; $i <= 3; $i++) {
            $cabang[] = \App\Models\Branch::create([
                'nama' => "Earth Petshop Cabang $i",
            ]);
        }

        // 2. Buat Admin
        User::create([
            'nama' => 'Admin Earth',
            'email' => 'admin@earthpetshop.com',
            'kata_sandi' => \Illuminate\Support\Facades\Hash::make('password'),
            'peran' => 'admin',
            'id_cabang' => null,
        ]);

        // 3. Buat Kasir
        foreach ($cabang as $index => $cab) {
            User::create([
                'nama' => "Kasir " . ($index + 1),
                'email' => "kasir" . ($index + 1) . "@earthpetshop.com",
                'kata_sandi' => \Illuminate\Support\Facades\Hash::make('password'),
                'peran' => 'kasir',
                'id_cabang' => $cab->id,
            ]);
        }

        // 4. Buat Produk Awal
        $itemMakananKucing = [
            ['nama' => 'Whiskas Adult Tuna', 'harga' => 25000, 'deskripsi' => 'Makanan kucing rasa tuna'],
            ['nama' => 'Royal Canin Mother & Baby', 'harga' => 150000, 'deskripsi' => 'Makanan premium untuk anak kucing'],
            ['nama' => 'Me-O Cat Food', 'harga' => 35000, 'deskripsi' => 'Makanan bergizi rasa seafood'],
            ['nama' => 'Pro Plan Kitten', 'harga' => 120000, 'deskripsi' => 'Protein tinggi untuk pertumbuhan'],
        ];

        foreach ($cabang as $cab) {
            foreach ($itemMakananKucing as $item) {
                \App\Models\Product::create([
                    'nama' => $item['nama'],
                    'deskripsi' => $item['deskripsi'],
                    'harga' => $item['harga'],
                    'stok' => 50,
                    'id_cabang' => $cab->id,
                    'path_gambar' => null,
                ]);
            }

            // Isi data layanan
            $layanan = [
                ['nama' => 'Grooming Mandi Sehat', 'harga' => 50000, 'deskripsi' => 'Paket mandi standar kucing agar bersih dan wangi'],
                ['nama' => 'Grooming Mandi Kutu/Jamur', 'harga' => 75000, 'deskripsi' => 'Mandi khusus dengan sampo anti kutu dan jamur kucing'],
                ['nama' => 'Pet Hotel Standard (Kandang AC)', 'harga' => 45000, 'deskripsi' => 'Fasilitas kandang bersih standar ber-AC untuk kucing'],
                ['nama' => 'Pet Hotel VIP (Kamar Bermain)', 'harga' => 85000, 'deskripsi' => 'Fasilitas kandang luas dengan playground ber-AC'],
            ];

            foreach ($layanan as $srv) {
                \App\Models\Product::create([
                    'nama' => $srv['nama'],
                    'deskripsi' => $srv['deskripsi'],
                    'harga' => $srv['harga'],
                    'stok' => 9999, // stok dummy tinggi untuk layanan
                    'id_cabang' => $cab->id,
                    'jenis' => 'layanan',
                    'path_gambar' => null,
                ]);
            }
        }
    }
}
