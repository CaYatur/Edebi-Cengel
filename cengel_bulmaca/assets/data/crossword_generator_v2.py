#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Crossword Grid Auto-Generator v2
Doğru cevaplar ve sorularla grid oluşturur
"""

import json
import random
from typing import Dict, List, Tuple, Set

class CrosswordCell:
    def __init__(self, row: int, col: int):
        self.row = row
        self.col = col
        self.letter = None
        self.across_word_id = None
        self.down_word_id = None

class CrosswordWord:
    def __init__(self, word_id: str, answer: str, question: str, direction: str, start_row: int, start_col: int, number: int):
        self.word_id = word_id
        self.answer = answer.upper()
        self.question = question
        self.direction = direction
        self.start_row = start_row
        self.start_col = start_col
        self.number = number

    def get_cells(self) -> List[Tuple[int, int]]:
        cells = []
        for i, _ in enumerate(self.answer):
            if self.direction == 'across':
                cells.append((self.start_row, self.start_col + i))
            else:  # down
                cells.append((self.start_row + i, self.start_col))
        return cells

class CrosswordGenerator:
    def __init__(self, grid_rows: int = 16, grid_cols: int = 16):
        self.grid_rows = grid_rows
        self.grid_cols = grid_cols
        self.grid: Dict[Tuple[int, int], CrosswordCell] = {}
        self.words: List[CrosswordWord] = []
        self.occupied_cells: Set[Tuple[int, int]] = set()

    def add_word(self, word_data: Dict) -> bool:
        """Kelimeyi grida ekle"""
        word_id = word_data.get('id', f'word_{len(self.words)}')
        answer = word_data.get('answer', '').upper()
        question = word_data.get('question', '')
        
        if not answer:
            return False

        # İlk kelimeyi ortaya yerleştir
        if not self.words:
            start_row = self.grid_rows // 2
            start_col = (self.grid_cols - len(answer)) // 2
            word = CrosswordWord(word_id, answer, question, 'across', start_row, start_col, 1)
            self.words.append(word)
            self._mark_cells(word)
            return True

        # Kesişim noktasını bul
        return self._place_with_intersection(word_data)

    def _place_with_intersection(self, word_data: Dict) -> bool:
        """Kesişim noktası kullanarak kelimeyi yerleştir - kompakt layout"""
        word_id = word_data.get('id', f'word_{len(self.words)}')
        answer = word_data.get('answer', '').upper()
        question = word_data.get('question', '')
        direction = 'down' if self.words[-1].direction == 'across' else 'across'

        # Stratejiler: önce başlangıç, sonra herhangi bir yer
        for strategy in ['boundaries', 'any']:
            for attempt in range(8000):
                ref_word = random.choice(self.words)
                
                # Strateji: başlangıç ve sonlara priority ver
                if strategy == 'boundaries':
                    # Kelime başı veya sonuna denk getir
                    candidate_indices = [0, len(ref_word.answer) - 1]
                    ref_idx = random.choice(candidate_indices)
                else:
                    # Herhangi bir yer
                    ref_idx = random.randint(0, len(ref_word.answer) - 1)
                
                ref_letter = ref_word.answer[ref_idx]
                matching_indices = [i for i, l in enumerate(answer) if l == ref_letter]
                
                if not matching_indices:
                    continue
                
                ans_idx = random.choice(matching_indices)
                
                # Kesişme noktasını hesapla
                if ref_word.direction == 'across':
                    new_row = ref_word.start_row - ans_idx
                    new_col = ref_word.start_col + ref_idx
                else:
                    new_row = ref_word.start_row + ref_idx
                    new_col = ref_word.start_col - ans_idx

                # Sınırları kontrol et
                if new_row < 0 or new_col < 0:
                    continue
                if direction == 'across' and new_col + len(answer) > self.grid_cols:
                    continue
                if direction == 'down' and new_row + len(answer) > self.grid_rows:
                    continue

                # Çakışma kontrolü
                if self._has_conflict(answer, direction, new_row, new_col):
                    continue

                # Yerleştir
                word = CrosswordWord(
                    word_id, answer, question, direction,
                    new_row, new_col, len(self.words) + 1
                )
                self.words.append(word)
                self._mark_cells(word)
                return True

        return False

    def _has_conflict(self, answer: str, direction: str, start_row: int, start_col: int) -> bool:
        """Çakışma var mı kontrol et"""
        for i, letter in enumerate(answer):
            if direction == 'across':
                cell_pos = (start_row, start_col + i)
            else:
                cell_pos = (start_row + i, start_col)

            if cell_pos in self.occupied_cells:
                # Harfler eşleşmeli
                cell = self.grid.get(cell_pos)
                if cell is None or cell.letter != letter:
                    return True

        return False

    def _mark_cells(self, word: CrosswordWord):
        """Kelimenin hücrelerini işaretle"""
        cells = word.get_cells()
        for i, (row, col) in enumerate(cells):
            pos = (row, col)
            if pos not in self.grid:
                self.grid[pos] = CrosswordCell(row, col)
            
            self.grid[pos].letter = word.answer[i]
            if word.direction == 'across':
                self.grid[pos].across_word_id = word.word_id
            else:
                self.grid[pos].down_word_id = word.word_id
            
            self.occupied_cells.add(pos)

    def generate_json(self) -> List[Dict]:
        """JSON formatında kelimeler listesi oluştur"""
        result = []
        for word in self.words:
            result.append({
                "id": word.word_id,
                "question": word.question,
                "answer": word.answer,
                "row": word.start_row,
                "col": word.start_col,
                "direction": word.direction,
                "number": word.number
            })
        return result

    def get_stats(self) -> Dict:
        """Grid istatistiklerini döndür"""
        if not self.words:
            return {}
        
        min_row = min(w.start_row for w in self.words)
        max_row = max(w.start_row + (len(w.answer) if w.direction == 'down' else 0) for w in self.words)
        min_col = min(w.start_col for w in self.words)
        max_col = max(w.start_col + (len(w.answer) if w.direction == 'across' else 0) for w in self.words)
        
        return {
            "word_count": len(self.words),
            "occupied_cells": len(self.occupied_cells),
            "min_row": min_row,
            "max_row": max_row,
            "min_col": min_col,
            "max_col": max_col,
        }


def generate_tanzimat_puzzles():
    """Tanzimat bulmacalarını oluştur - doğru sorular ve cevaplarla"""
    
    tanzimat_1_data = [
        {"id": "t1_1", "question": "Ziya Paşa'nın bir makalesidir. Ziya Paşa bu makalede divan edebiyatını eleştirmiştir.", "answer": "SIIRVEINSA"},
        {"id": "t1_2", "question": "Türk edebiyatında ilk tarihî roman", "answer": "CEZMI"},
        {"id": "t1_3", "question": "Tanzimat edebiyatı 1. dönem şairlerinden biri", "answer": "ZIYAPASA"},
        {"id": "t1_4", "question": "Realizmin şiire uyarlanmış şekli", "answer": "PARNASIZM"},
        {"id": "t1_5", "question": "Klasisizme tepki olarak doğan edebi akım", "answer": "REALIZM"},
        {"id": "t1_6", "question": "Makber, Garam, Hacıe adlı eserlerin türü", "answer": "SIIR"},
        {"id": "t1_7", "question": "Tanzimat edebiyatı döneminde şiirde .... ölçüsü kullanılmıştır", "answer": "ARUZ"},
    ]

    tanzimat_2_data = [
        {"id": "t2_1", "question": "Taaşşuk-ı Talat ve Fitnat, Kamus-ı Türki adlı eserlerin yazarı", "answer": "SEMSETTINSAMI"},
        {"id": "t2_2", "question": "Namık Kemal'in tiyatro eserlerinden biri", "answer": "KARABELA"},
        {"id": "t2_3", "question": "Tanzimat edebiyatının halkçı yazarıdır. Halkı bilgilendirmek ve eğitmek amacıyla hemen her konuda eserler vermiştir.", "answer": "AHMETMITHATEFENDI"},
        {"id": "t2_4", "question": "Tanzimat döneminde edebiyatımıza giren türlerden biridir.", "answer": "ELESTIRI"},
        {"id": "t2_5", "question": "Muallim Naci'nin anı türündeki eseri", "answer": "OMERINCOCUKLUGU"},
        {"id": "t2_6", "question": "Ahmet Mithat Efendi'nin çıkardığı gazetelerden biri", "answer": "TERCUMANIHAKIKAT"},
        {"id": "t2_7", "question": "Şinasi'nin şiirlerini topladığı eserinin adı", "answer": "MUNTHEEBATISIAR"},
    ]

    # Tanzimat-1 oluştur (18x18 grid)
    gen1 = CrosswordGenerator(18, 18)
    for data in tanzimat_1_data:
        gen1.add_word(data)
    
    print("Tanzimat-1 İstatistikleri:", gen1.get_stats())
    tanzimat_1_words = gen1.generate_json()

    # Tanzimat-2 oluştur (18x18 grid)
    gen2 = CrosswordGenerator(18, 18)
    for data in tanzimat_2_data:
        gen2.add_word(data)
    
    print("Tanzimat-2 İstatistikleri:", gen2.get_stats())
    tanzimat_2_words = gen2.generate_json()

    return tanzimat_1_words, tanzimat_2_words


def generate_cumhuriyet_1_puzzle():
    """Cumhuriyet Dönemi 1 puzzle setini oluştur"""
    cumhuriyet_1_data = [
        {"id": "c1_1", "question": "Şiirde iç ahengi üstün tutan, nazmı nesirden uzaklaştıran şair, biçim mükemmelliğini aramış, sözcükleri bir kuyumcu titizliğiyle seçmiştir. Öz şiirin öncülerinden olan şairin şiir kitaplarından biri Kendi Gök Kubbemiz'dir. Yahya Kemal ...", "answer": "BEYATLI"},
        {"id": "c1_2", "question": "Ahmet Hamdi Tanpınar'ın \"Beş Şehir\" adlı eserinin türü", "answer": "DENEME"},
        {"id": "c1_3", "question": "Necip Fazıl Kısakürek'in bir tiyatro eseri. BİR ADAM ...", "answer": "YARATMAK"},
        {"id": "c1_4", "question": "Ahmet Hamdi Tanpınar'ın bir romanı", "answer": "HUZUR"},
        {"id": "c1_5", "question": "Şiirde dizelerin hece sayılarının eşitliğine dayalı ölçü.", "answer": "HECEOLCUSU"},
        {"id": "c1_6", "question": "Şiirlerinde korkusunu, yaşama sevincini işleyen şairin şiir kitaplarından biri Düşten Güzel'dir.", "answer": "CAHITSITKITARANCI"},
        {"id": "c1_7", "question": "Öz şiiri benimseyen şairler, sanat için . anlayışıyla yazarlar", "answer": "SANAT"},
    ]

    gen = CrosswordGenerator(18, 18)
    for data in cumhuriyet_1_data:
        gen.add_word(data)
    
    print("Cumhuriyet-1 İstatistikleri:", gen.get_stats())
    return gen.generate_json()


def generate_divan_edebiyati_puzzle():
    """Divan Edebiyatı puzzle setini oluştur"""
    divan_data = [
        {"id": "d1_1", "question": "Divan edebiyatı nazım biçimi. Bu türün ilk ve en güzel örneklerini Nedim vermiştir.", "answer": "SARKI"},
        {"id": "d1_2", "question": "Afyon ile şarabın karşılaştırılıp şarabın üstünlüğünün anlatıldığı eser Şah İsmail'e sunulmuştur.", "answer": "BENGUBADE"},
        {"id": "d1_3", "question": "16. yüzyılda yaşamış Şairler Sultanı olarak bilinen divan şairi", "answer": "BAKI"},
        {"id": "d1_4", "question": "Divan edebiyatı nesrinde uyak.", "answer": "SECI"},
        {"id": "d1_5", "question": "Hacı Bektaş-ı Veli'nin tasavvufi, dinî-ahlaki eserinin adı.", "answer": "MAKALAT"},
        {"id": "d1_6", "question": "Sebk-i Hindi akımının 17. yüzyıldaki temsilcilerinden biri.", "answer": "NEFI"},
        {"id": "d1_7", "question": "Lale Devri'nde yaşamış, şarkının ilk örneklerini vermiş divan şairi", "answer": "NEDIM"},
    ]

    gen = CrosswordGenerator(18, 18)
    for data in divan_data:
        gen.add_word(data)
    
    print("Divan Edebiyatı İstatistikleri:", gen.get_stats())
    return gen.generate_json()


if __name__ == '__main__':
    t1_words, t2_words = generate_tanzimat_puzzles()
    c1_words = generate_cumhuriyet_1_puzzle()
    d1_words = generate_divan_edebiyati_puzzle()
    
    print("\n=== Tanzimat-1 Kelimeler ===")
    print(json.dumps(t1_words, indent=2, ensure_ascii=False))
    
    print("\n=== Tanzimat-2 Kelimeler ===")
    print(json.dumps(t2_words, indent=2, ensure_ascii=False))
    
    print("\n=== Cumhuriyet-1 Kelimeler ===")
    print(json.dumps(c1_words, indent=2, ensure_ascii=False))
    
    print("\n=== Divan Edebiyatı Kelimeler ===")
    print(json.dumps(d1_words, indent=2, ensure_ascii=False))
