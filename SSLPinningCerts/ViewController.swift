//
//  ViewController.swift
//  SSLPinningCerts
//
//  Created by Pradeep kumar on 16/8/23.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        getNews()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            print("called dealy one after 5 seconds")
            self.getNews()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            print("called dealy one after 10 seconds")
            self.getNews()
        }

    }
    
    let network = NetworkManger()

    func getNews() {
        network.getNewsAPI(_type: NewsData.self) { result in
            switch result {
            case .success(let data):
                print("news data \(data.articles.count)")
            case .failure(let error):
                print("error \(error.localizedDescription)")
            }
        }
    }

}



struct NewsData: Decodable {
    
    let status: String?
    let totalResults: Int?
    let articles: [Articles]
    
    struct Articles: Decodable {
        let author: String?
        let title: String?
        let description: String?
        
    }
}
