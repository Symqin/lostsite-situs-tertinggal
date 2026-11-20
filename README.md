# Lostsite: Situs Ter Tinggal

Proyek Final Codelamp 2D Godot Game Development Bootcamp — Kelompok 1.

Game *tower defense* bergenre horor/komedi. Pemain berperan sebagai hantu yang
menjaga sebuah situs terbengkalai dari para **pengunjung** yang nekat masuk.
Tempatkan hantu-hantu penjaga untuk menakut-nakuti pengunjung sebelum mereka
mencapai inti (Core) dan menghancurkannya.

## Fitur Utama

- **4 level** dengan jalur (route) musuh yang berbeda-beda per level
- **3 hantu penjaga** dengan peran dan kemampuan unik
- **3 tipe musuh** dengan kelemahan dan perilaku berbeda
- **Interaksi ruangan**: matikan lampu dan bisikan untuk membantu pertahanan
- Sistem gelombang (wave) dengan formasi spawn dan jadwal musuh
- Panduan pemain: panel bantuan, tooltip stat, dan petunjuk penempatan
- Sistem energi teror sebagai sumber daya untuk menempatkan hantu

## Cara Bermain

1. Klik hantu di panel kiri lalu letakkan di area yang tersorot di peta.
2. Hantu otomatis menyerang pengunjung dalam jangkauannya dengan **Fear Damage**.
3. Pengunjung yang takutnya habis akan **kabur** kembali ke titik spawn.
4. Setiap pengunjung yang kabur memberi **Terror Energy** — gunakan untuk
   menempatkan hantu baru atau memindahkan hantu yang sudah ada.
5. Bertahanlah sampai semua gelombang selesai. Jika Core hancur, permainan berakhir.

## Hantu Penjaga

| Hantu | Biaya | Damage | Serangan | Peran |
|-------|-------|--------|----------|-------|
| **Pocong** | 40 | 10 | 1.0/detik | Cepat & murah, penjaga tikungan |
| **Kuntilanak** | 60 | 20 | 1.0/3 detik | Lambat tapi serangannya sangat menakutkan |
| **Tuyul** | 30 | 5 | 1.0/2 detik | Pendukung, menguatkan hantu lain |

### Kemampuan Khusus

- **Pocong — Haunted Stomp**: Menyerang hingga 4 pengunjung terdekat
  (+35 takut) dan mendorong mundur 2 langkah. Cooldown awal 10 detik,
  selanjutnya 90 detik.
- **Kuntilanak — Dreadful Scream**: Semua pengunjung di sekitar mendapat
  +25 takut dan membeku selama 5 detik. Cooldown awal 20 detik, selanjutnya 180 detik.
- **Tuyul — Steal**: Hantu di sekitarnya mendapat +10 damage selama 12 detik;
  pengunjung yang kabur memberi energi ekstra. Cooldown awal 10 detik, selanjutnya 270 detik.

Kemampuan aktif bisa dipicu lewat tombol kemampuan di HUD (bukan tombol menu
biasa). Butuh hantu yang sudah ditempatkan di dekat target.

## Interaksi Ruangan

- **Lampu (matikan lampu)**: 30 energi. Hantu di dalam ruangan mendapat damage
  ×1.5 selama 5 detik. Cooldown 10 detik.
- **Bisikan**: 20 energi. Pengunjung di ruangan +10 takut dan berhenti 1.5 detik.
  Cooldown 8 detik.

## Musuh

| Musuh | Fear (HP) | Kecepatan | Energi | Keistimewaan |
|-------|-----------|-----------|--------|--------------|
| **Pengunjung** | 30 | 50 | 15 | Tidak ada |
| **Vlogger** | 45 | 70 | 20 | Kebal setengah terhadap jebakan Ruangan |
| **Dukun** | 150 | 70 | 50 | Menahan setengah rasa takut, membekukan hantu di dekatnya 2 detik |

Semua musuh berjalan mengikuti waypoint menuju Core. Saat takut habis mereka
kabur kembali ke spawn; jika berhasil sampai di Core, Core rusak.

## Cara Menjalankan

1. Buka Godot 4.6 (GL Compatibility).
2. Import folder `CodelampProject/` sebagai proyek.
3. Tekan **F5** (Run Project).

## Struktur Proyek

```
CodelampProject/
├── ghosts/          # Hantu penjaga (Pocong, Kuntilanak, Tuyul)
├── enemies/         # Musuh (Pengunjung, Vlogger, Dukun)
├── levels/          # Definisi level, waypoint, dan route musuh
├── waves/           # Data gelombang (WaveData, SpawnEntry)
├── interactables/   # Interaksi ruangan (lampu & bisikan)
├── globals/         # Autoload: AudioManager, SignalHub, GameManager
├── ui/              # HUD, title screen, level select, help/guide, dll.
└── main.gd          # Logika utama permainan (spawn, gelombang, energi)
```

## Teknologi

- **Engine**: Godot 4.6 (GDScript)
- **Renderer**: GL Compatibility
- **Asset**: Sprite & audio buatan tim

## Tim Kelompok 1

Project final Codelamp 2D Godot Game Development Bootcamp.