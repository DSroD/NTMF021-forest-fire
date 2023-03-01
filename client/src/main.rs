use std::collections::VecDeque;
use std::time::Instant;
use clap::arg;
use serde::{Deserialize, Serialize};
use reqwest::blocking::Client;

fn main() {
    let args = clap::Command::new("Fire-at-Home Client")
        .version("0.1")
        .author("Daniel Rod")
        .about("Compute my HW please.")
        .arg(arg!(--name <VALUE>).required(true))
        .get_matches();

    let name = args.get_one::<String>("name").expect("Parameter name is required");
    let client = Client::builder().build().unwrap();

    loop {
        let job = get_job(&client, name).unwrap();
        println!("Received job {} (grid: {}, p: {})", job.job_id, job.grid_size, job.tree_probability);
        let now = Instant::now();
        let results: Vec<u16> = (0 .. 2048).map(|_|
            Grid::generate(job.grid_size, job.tree_probability).burn()).collect();
        let sum: f64 = results.iter().map(|res| (*res as f64)).collect::<Vec<f64>>().iter().sum();
        let avg = sum / (results.len() as f64);
        let after = now.elapsed().as_secs_f64();
        let _ = post_result(&client, &name, job.job_id, ComputationResult {
                result: avg,
                elapsed: after
        });
    }

}

fn get_job(client: &Client, name: &str) -> reqwest::Result<Job> {
    client.get(format!("https://fire-at-home.dsrod.cz/queue/{}", name))
        .send()?.json::<Job>()
}

fn post_result(client: &Client, name: &str, job_id: i64, result: ComputationResult ) -> reqwest::blocking::Response {
    client.post(format!("https://fire-at-home.dsrod.cz/result/{}/{}", name, job_id))
        .json(&result).send().unwrap()
}

#[derive(PartialEq)]
enum Cell {
    Empty,
    Tree,
    Burning,
}

#[derive(Deserialize)]
struct Job {
    #[serde(rename = "job-id")]
    job_id: i64,
    #[serde(rename = "grid-size")]
    grid_size: usize,
    #[serde(rename = "tree-probability")]
    tree_probability: f64,
}

#[derive(Serialize)]
struct ComputationResult {
    result: f64,
    elapsed: f64,
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