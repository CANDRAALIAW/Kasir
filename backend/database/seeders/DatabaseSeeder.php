<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // 1. Create Branches
        $branches = [];
        for ($i = 1; $i <= 3; $i++) {
            $branches[] = \App\Models\Branch::create([
                'name' => "Earth Petshop Branch $i",
            ]);
        }

        // 2. Create Admin
        \App\Models\User::create([
            'name' => 'Admin Earth',
            'email' => 'admin@earthpetshop.com',
            'password' => \Illuminate\Support\Facades\Hash::make('password'),
            'role' => 'admin',
            'branch_id' => null,
        ]);

        // 3. Create Cashiers
        foreach ($branches as $index => $branch) {
            \App\Models\User::create([
                'name' => "Kasir " . ($index + 1),
                'email' => "kasir" . ($index + 1) . "@earthpetshop.com",
                'password' => \Illuminate\Support\Facades\Hash::make('password'),
                'role' => 'kasir',
                'branch_id' => $branch->id,
            ]);
        }

        // 4. Create Initial Products
        $catFoodItems = [
            ['name' => 'Whiskas Adult Tuna', 'price' => 25000, 'description' => 'Tuna flavored cat food'],
            ['name' => 'Royal Canin Mother & Baby', 'price' => 150000, 'description' => 'Premium food for kittens'],
            ['name' => 'Me-O Cat Food', 'price' => 35000, 'description' => 'Nutritious seafood flavor'],
            ['name' => 'Pro Plan Kitten', 'price' => 120000, 'description' => 'High protein for growth'],
        ];

        foreach ($branches as $branch) {
            foreach ($catFoodItems as $item) {
                \App\Models\Product::create([
                    'name' => $item['name'],
                    'description' => $item['description'],
                    'price' => $item['price'],
                    'stock' => 50,
                    'branch_id' => $branch->id,
                    'image_path' => null,
                ]);
            }

            // Seed services
            $services = [
                ['name' => 'Grooming Mandi Sehat', 'price' => 50000, 'description' => 'Paket mandi standar kucing agar bersih dan wangi'],
                ['name' => 'Grooming Mandi Kutu/Jamur', 'price' => 75000, 'description' => 'Mandi khusus dengan sampo anti kutu dan jamur kucing'],
                ['name' => 'Pet Hotel Standard (Kandang AC)', 'price' => 45000, 'description' => 'Fasilitas kandang bersih standar ber-AC untuk kucing'],
                ['name' => 'Pet Hotel VIP (Kamar Bermain)', 'price' => 85000, 'description' => 'Fasilitas kandang luas dengan playground ber-AC'],
            ];

            foreach ($services as $service) {
                \App\Models\Product::create([
                    'name' => $service['name'],
                    'description' => $service['description'],
                    'price' => $service['price'],
                    'stock' => 9999, // dummy high stock for services
                    'branch_id' => $branch->id,
                    'type' => 'service',
                    'image_path' => null,
                ]);
            }
        }
    }
}
