fn main() {
    for (i, argument) in std::env::args().enumerate() {
        println!("Rust [{}] -> [{}]", i, argument);
    }
    // let mut buf = String::new();
    // std::io::stdin().read_line(&mut buf).unwrap();
}
