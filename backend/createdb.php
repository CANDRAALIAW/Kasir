<?php
try {
    $pdo = new PDO('mysql:host=127.0.0.1;port=3306', 'root', '');
    $pdo->exec('CREATE DATABASE IF NOT EXISTS db_earth_petshop');
    echo "Database created successfully\n";
} catch (PDOException $e) {
    echo $e->getMessage() . "\n";
}
