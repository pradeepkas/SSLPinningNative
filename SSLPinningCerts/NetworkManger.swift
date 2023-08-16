//
//  NetworkManger.swift
//  SSLPinningCerts
//
//  Created by Pradeep kumar on 16/8/23.
//

import Foundation

enum APIError: Error {
    case noRequest
    case noData
    case noURL
    case decoderError
    case message(String)
}

enum RequestHandler: String {
    case getNews
    
    private var basePath: String {
        "https://newsapi.org/v2/everything"
    }
    
    private var key: String {
        "e3d69af3aea04d0384ea776453a8c321"
    }
    
    func makeRequest() -> URLRequest? {
        let queryItems = [URLQueryItem(name: "q", value: "tesla"),
                          URLQueryItem(name: "from", value: "2023-07-16"),
                          URLQueryItem(name: "sortBy", value: "publishedAt"),
                          URLQueryItem(name: "apiKey", value: key)]
        
        var urlComponent = URLComponents(string: basePath)
        urlComponent?.queryItems = queryItems
        
        if let url = urlComponent?.url {
            return URLRequest(url: (url))
        }
        return nil
    }
}

class NetworkManger: NSObject {
    
    var session: URLSession?
    let certificateFetch: LocalCertificate
    
    init(_ certificateFetch: LocalCertificate = LocalCertificateFetcher()) {
        self.certificateFetch = certificateFetch
        super.init()
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }
        
    func getNewsAPI<T:Decodable>(_type: T.Type, handler: @escaping (Result<T, APIError>) -> Void ) {
                
        guard let req = RequestHandler.getNews.makeRequest() else {
            handler(.failure(.noRequest))
            return
        }
        
        session?.dataTask(with: req) { data, response, error in
            
            if let error = error {
                handler(.failure(.message(error.localizedDescription)))
                return
            }
            
            guard let res = response as? HTTPURLResponse, (200...299) ~= res.statusCode else {
                handler(.failure(.noRequest))
                return
            }
            
            guard let data = data else {
                handler(.failure(.noData))
                return
            }
            
            do {
                let result = try JSONDecoder().decode(_type.self, from: data)
                handler(.success(result))

            } catch let error {
                handler(.failure(.message(error.localizedDescription)))
            }
        }
        .resume()
        
    }
    
}

extension NetworkManger: URLSessionDelegate {
     
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return
        }
        
        // 0 means we want only leaf certificate from list
        
        // Set SSL policies for domain name check
        let policies = NSMutableArray()
        policies.add(SecPolicyCreateSSL(true, (challenge.protectionSpace.host as CFString)))
        SecTrustSetPolicies(serverTrust, policies)
        
        // certificate Pinning
                    
        let isServerTrust = SecTrustEvaluateWithError(serverTrust, nil)
        
        // local and server data
        // evalutate the certificate
        let remoteCertData: NSData = SecCertificateCopyData(serverCertificate)
        let localCertData: NSData = certificateFetch.getLocalCertData()
        
        // compare both data
        if isServerTrust && remoteCertData.isEqual(to: localCertData as Data) {
            let credential = URLCredential(trust: serverTrust)
            print("certificate pinning is successful")
            completionHandler(.useCredential, credential
            )
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
}


protocol LocalCertificate {
    func getLocalCertData() -> NSData
}

class LocalCertificateFetcher: LocalCertificate {
    
    func getLocalCertData() -> NSData {
        let pathToCertificate = Bundle.main.path(forResource: "sni.cloudflaressl.com", ofType: ".cer") ?? ""
        let data = NSData(contentsOfFile: pathToCertificate)
        return data! // can handle this but for now we are sure
    }

}
