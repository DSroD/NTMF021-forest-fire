use std::collections::VecDeque;
use std::fmt::format;
use http::Request;

#[tokio::main]
fn main() {
    let k = Grid::generate(4096, 0.4).burn();
    println!("{}", k)
}

fn getJob(name: &str) {
    let url = format!("http://localhost/queue/{}", name).parse::<hyper::Uri>()?;
    let host = url.host().expect("Wrong url...");
    let port = 8000;

    

}

#[derive(PartialEq)]
enum Cell {
    Empty,
    Tree,
    Burning,
}

#[derive(Deserialize)]
struct Job {
    job_id: i64,
    grid_size: usize,
    tree_probability: f64,
}

#[derive(Serialize)]
struct Result {
    result: f64,
    elapsed: f64,
}

fn get_job(name: &str) -> Option<Job> {

}

struct BurningTree {
    pub x: usize,
    pub y: usize,
    pub generation: u16,
}

struct Grid {
    forest: Box<[Cell]>,
    side: usize,
    burning: VecDeque<BurningTree>
}

impl Grid {

    pub fn generate(n: usize, p: f64) -> Grid {
        let mut bc = VecDeque::with_capacity(5 * n);
        let fr = (0 .. n * n).map(|idx| {
            if rand::random::<f64>() < p {
                if idx < n {
                    bc.push_back(BurningTree {
                        x: idx,
                        y: 0,
                        generation: 0
                    });
                    Cell::Burning
                } else {
                    Cell::Tree
                }
            } else {
                Cell::Empty
            }
        }).collect();

        Grid {
            forest: fr,
            side: n,
            burning: bc
        }
    }

    fn set_burning(&mut self, x: usize, y: usize) {
        self.forest[y * self.side + x] = Cell::Burning;
    }

    fn is_tree(&self, x: usize, y: usize) -> bool {
        self.forest[y * self.side + x] == Cell::Tree
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
    pub fn burn(&mut self) -> u16 {
        let mut last_gen: u16 = 0;
        while !self.burning.is_empty() {
            let ct = self.burning.pop_front().unwrap();
            last_gen = ct.generation;
            // Right and down - push front with same "generation"
            // Right has to be after down so it gets on the top of the stack
            // Down
            if ct.x < self.side-1 && self.is_tree(ct.x + 1, ct.y) {
                self.set_burning(ct.x + 1, ct.y);
                self.push_front(ct.x + 1, ct.y, ct.generation);
            }
            // Right
            if ct.y < self.side-1 && self.is_tree(ct.x, ct.y + 1) {
                self.set_burning(ct.x, ct.y + 1);
                self.push_front(ct.x, ct.y + 1, ct.generation);
            }
            // Left and up - push back with next "generation"
            // Up
            if ct.y > 0 && self.is_tree(ct.x, ct.y - 1) {
                self.set_burning(ct.x, ct.y - 1);
                self.push_back(ct.x, ct.y - 1, ct.generation + 1);
            }
            // Left
            if ct.x > 0 && self.is_tree(ct.x - 1, ct.y) {
                self.set_burning(ct.x - 1, ct.y);
                self.push_back(ct.x - 1, ct.y, ct.generation + 1);
            }
        }
        last_gen
    }
}