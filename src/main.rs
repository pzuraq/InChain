extern crate curl;
extern crate serialize;

use std::str;
use std::io::Timer;
use std::time::Duration;
use curl::http;
use serialize::json;
use base58::{ToBase58, FromBase58};

mod base58;

// Structs used to interpret JSON

#[deriving(Decodable, Encodable)]
pub struct Response {
  txs: Vec<Transaction>
}

#[deriving(Decodable, Encodable)]
pub struct Transaction {
	out: Vec<OutTransaction>
}

#[deriving(Decodable, Encodable)]
pub struct OutTransaction {
	addr: String,
	value: u32
}

fn main() {
	let address = "14L55Bu9f4LsCS7ddK8FfftACYvGjyWWcC";

	let mut timer = Timer::new().unwrap();
	let periodic = timer.periodic(Duration::seconds(5));

	loop {
		periodic.recv();

		let resp = http::handle().get(format!("https://blockchain.info/address/{}?sort=0&filter=1&format=json", address)).exec().unwrap();
		let json_resp = match str::from_utf8(resp.get_body()) {
	    Some(e) => e,
	    None => panic!("Invalid UTF-8 sequence"),
		};
		let decoded_resp: Response = json::decode(json_resp).unwrap();

	 	println!("{}", decoded_resp.txs[0].out[0].addr);
	 	println!("{}", decoded_resp.txs[0].out[0].value);

	  println!("{}", FromBase58::from_base58(decoded_resp.txs[0].out[0].addr.as_slice()));

	} 	
}