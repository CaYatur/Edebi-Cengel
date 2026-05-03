#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Crossword Grid Auto-Generator
Kelimeler arasında kesişim noktaları bularak rastgele ve mantıklı grid oluşturur
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
    """Tanzimat bulmacalarını oluştur - kompakt layout"""
    
    tanzimat_1_data = [
        {"id": "t1_1", "question": "Ziya Paşa'nın bir makalesidir. Ziya Paşa bu makalede divan edebiyatını eleştirmiştir.", "answer": "SURVEYNSA"},
        {"id": "t1_2", "question": "Türk edebiyatında ilk tarihî roman", "answer": "CEREMI"},
        {"id": "t1_3", "question": "Tanzimat edebiyatı 1. dönem şairlerinden biri", "answer": "ZIYAPASA"},
        {"id": "t1_4", "question": "Realizmin şiire uyarlanmış şekli", "answer": "PARNASIZM"},
        {"id": "t1_5", "question": "Klasisizme tepki olarak doğan edebi akım", "answer": "REALIZM"},
        {"id": "t1_6", "question": "Makber, Garam, Hacıe adlı eserlerin türü", "answer": "SIR"},
        {"id": "t1_7", "question": "Tanzimat edebiyatı döneminde şirde .... ölçüsü kullanılmıştır", "answer": "ARUZ"},
    ]

    tanzimat_2_data = [
        {"id": "t2_1", "question": "Taaşşuk-ı Talat ve Fitnat, Kamış-ı Türki adlı eserlerin yazarı", "answer": "SEMSETTINSAMI"},
        {"id": "t2_2", "question": "Namık Kemal'in tiyatro eserlerinden biri", "answer": "KARABELA"},
        {"id": "t2_3", "question": "Tanzimat edebiyatı halkçı yazarı. Halka yaklaşmak ve eğitmek amacıyla eserler vermiştir.", "answer": "AHMETMITHAT"},
        {"id": "t2_4", "question": "Tanzimat döneminde edebiyata giren yeni edebi tür", "answer": "ROMAN"},
        {"id": "t2_5", "question": "Ahmet Mithat Efendi'nin halka yaklaştığı yazılarından biri", "answer": "TERCUMAN"},
        {"id": "t2_6", "question": "Sinası'nın şiirlerini topladığı eserinin adı", "answer": "MUNTEHEBATISIAR"},
        {"id": "t2_7", "question": "Tanzimat döneminin önemli gazetesi", "answer": "TAKVIM"},
    ]

    # Tanzimat-1 oluştur (18x18 grid - kompakt ama yeterli)
    gen1 = CrosswordGenerator(18, 18)
    for data in tanzimat_1_data:
        gen1.add_word(data)
    
    print("Tanzimat-1 İstatistikleri:", gen1.get_stats())
    tanzimat_1_words = gen1.generate_json()

    # Tanzimat-2 oluştur (18x18 grid - kompakt ama yeterli)
    gen2 = CrosswordGenerator(18, 18)
    for data in tanzimat_2_data:
        gen2.add_word(data)
    
    print("Tanzimat-2 İstatistikleri:", gen2.get_stats())
    tanzimat_2_words = gen2.generate_json()

    return tanzimat_1_words, tanzimat_2_words


if __name__ == '__main__':
    t1_words, t2_words = generate_tanzimat_puzzles()
    
    print("\n=== Tanzimat-1 Kelimeler ===")
    print(json.dumps(t1_words, indent=2, ensure_ascii=False))
    
    print("\n=== Tanzimat-2 Kelimeler ===")
    print(json.dumps(t2_words, indent=2, ensure_ascii=False))
