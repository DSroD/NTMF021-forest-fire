#![feature(generic_const_exprs)]

use std::collections::VecDeque;

fn main() {

}
#[derive(PartialEq)]
enum Cell {
    Empty,
    Tree,
    Burning,
}

fn getGrid(n: usize, p: f64) {
    let g = match n {
        8 => Grid { forest), burning: val }
    }
}

struct BurningTree {
    pub x: usize,
    pub y: usize,
    pub generation: u16,
}

struct Grid<const N: usize> {
    forest: [[Cell; N]; N],
    burning: VecDeque<BurningTree>
}

impl<const N: usize> Grid<N> {

    fn generate(p: f64) {
        let bc = &mut VecDeque::with_capacity(5 * N);

    }

    fn set_burning(&mut self, x: usize, y: usize) {
        self.forest[x][y] = Cell::Burning;
    }

    fn push_front(&mut self, x: usize, y: usize, generation: u16) {
        self.burning.push_front(BurningTree {
            x,
            y,
            generation,
        })
    }

    fn push_back(&mut self, x: usize, y: usize, generation: u16) {
        self.burning.push_back(BurningTree {
            x,
            y,
            generation
        })
    }

    // This is more effective than going through the grid all the time
    // as we are only going through the burning trees
    fn burn(&mut self) -> u16 {
        let mut last_gen: u16 = 0;
        while !self.burning.is_empty() {
            let ct = self.burning.pop_front().unwrap();
            last_gen = ct.generation;
            // Right and down - push front with same "generation"
            // Right has to be after down so it gets on the top of the stack
            // Down
            if ct.x < N-1 && self.forest[ct.x + 1][ct.y] == Cell::Tree {
                self.set_burning(ct.x + 1, ct.y);
                self.push_front(ct.x + 1, ct.y, ct.generation);
            }
            // Right
            if ct.y < N-1 && self.forest[ct.x][ct.y + 1] == Cell::Tree {
                self.set_burning(ct.x, ct.y + 1);
                self.push_front(ct.x, ct.y + 1, ct.generation);
            }
            // Left and up - push back with next "generation"
            // Up
            if ct.y > 0 && self.forest[ct.x][ct.y - 1] == Cell::Tree {
                self.set_burning(ct.x, ct.y - 1);
                self.push_back(ct.x, ct.y - 1, ct.generation + 1);
            }
            // Left
            if ct.x > 0 && self.forest[ct.x - 1][ct.y] == Cell::Tree {
                self.set_burning(ct.x - 1, ct.y);
                self.push_back(ct.x - 1, ct.y, ct.generation + 1);
            }
        }
        last_gen
    }
}