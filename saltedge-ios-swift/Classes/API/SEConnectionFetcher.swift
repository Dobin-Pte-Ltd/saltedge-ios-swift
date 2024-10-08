//
//  SEConnectionFetcher.swift
//
//  Copyright (c) 2019 Salt Edge. https://saltedge.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation


class SEConnectionFetcher {
    private static let pollingInterval: Double = 3.0
    private static var pollingRetryCount: Int = 0
    private static let pollingRetryMax: Int = 10
    
    static func createConnection(
        with params: SEConnectionParams,
        fetchingDelegate: SEConnectionFetchingDelegate,
        completion: SEHTTPResponse<SEConnection>
    ) {
        HTTPService<SEConnection>.makeRequest(ConnectionRouter.create(params)) { response in
            switch response {
            case .success(let value):
                completion?(.success(value))
                self.requestPolling(for: value.data, fetchingDelegate: fetchingDelegate)
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    static func updateConnectionStatus(
        with params: SEConnectionUpdateStatusParams,
        id: String,
        secret: String,
        fetchingDelegate: SEConnectionFetchingDelegate,
        completion: SEHTTPResponse<SEConnection>
    ) {
        HTTPService<SEConnection>.makeRequest(ConnectionRouter.update(params, id, secret)) { response in
            switch response {
            case .success(let value):
                self.requestPolling(for: value.data, fetchingDelegate: fetchingDelegate)
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    static func reconnectConnection(
        secret: String,
        params: SEConnectionReconnectParams,
        fetchingDelegate: SEConnectionFetchingDelegate,
        completion: SEHTTPResponse<SEConnection>
    ) {
        HTTPService<SEConnection>.makeRequest(ConnectionRouter.reconnect(params, secret)) { response in
            switch response {
            case .success(let value):
                self.requestPolling(for: value.data, fetchingDelegate: fetchingDelegate)
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    static func refreshConnection(
        secret: String,
        params: SEConnectionRefreshParams? = nil,
        fetchingDelegate: SEConnectionFetchingDelegate,
        completion: SEHTTPResponse<SEConnection>
    ) {
        HTTPService<SEConnection>.makeRequest(ConnectionRouter.refresh(params, secret)) { response in
            switch response {
            case .success(let value):
                self.requestPolling(for: value.data, fetchingDelegate: fetchingDelegate)
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    static func interactiveConnection(
        with params: SEConnectionInteractiveParams,
        secret: String,
        fetchingDelegate: SEConnectionFetchingDelegate,
        completion: SEHTTPResponse<SEConnection>
    ) {
        HTTPService<SEConnection>.makeRequest(ConnectionRouter.interactive(params, secret)) { response in
            switch response {
            case .success(let value):
                self.requestPolling(for: value.data, fetchingDelegate: fetchingDelegate)
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
    
    static func handleOAuthConnection(connectionSecret: String, fetchingDelegate: SEConnectionFetchingDelegate) {
        self.pollConnection(connectionSecret, fetchingDelegate: fetchingDelegate)
    }
    
    private static func requestPolling(for connection: SEConnection, fetchingDelegate: SEConnectionFetchingDelegate) {
        fetchingDelegate.logMessage("SALTEDGE - \(connection.providerCode) - SHOULD POLL CONNECTION IN \(SEConnectionFetcher.pollingInterval) SECONDS")
        DispatchQueue.global(qos: .background).asyncAfter(wallDeadline: .now() + SEConnectionFetcher.pollingInterval, execute: {
            self.pollConnection(connection.secret, fetchingDelegate: fetchingDelegate)
        })
    }
    
    private static func pollConnection(_ connectionSecret: String, fetchingDelegate: SEConnectionFetchingDelegate) {
        
        fetchingDelegate.logMessage("SALTEDGE POLLING CONNECTION")
        HTTPService<SEConnection>.makeRequest(ConnectionRouter.show(connectionSecret)) { response in
            switch response {
                
            case .success(let value):
                pollingRetryCount = 0
                fetchingDelegate.logMessage("SALTEDGE POLLING CONNECTION SUCCESS")
                self.handleSuccessPollResponse(for: value.data, fetchingDelegate: fetchingDelegate)
                
            case .failure(let error):
                // ignore error if:
                // Error Domain=NSURLErrorDomain Code=-1005 "The network connection was lost."
                // will just try to poll again
                if pollingRetryCount < pollingRetryMax &&
                    ((error as NSError).code == -1005 ||  error.localizedDescription == "The network connection was lost." || (error as NSError).code == -1001 ||  error.localizedDescription == "The request timed out.") {
                    
                    pollingRetryCount += 1
                    
                    fetchingDelegate.logMessage("SALTEDGE POLLING CONNECTION LOST / TIMED OUT - WILL RETRY (\(pollingRetryCount)) in 5 sec")
                    
                    DispatchQueue.global(qos: .background).asyncAfter(wallDeadline: .now() + SEConnectionFetcher.pollingInterval, execute: {
                        self.pollConnection(connectionSecret, fetchingDelegate: fetchingDelegate)
                    })
                    
                } else {
                    pollingRetryCount = 0
                    fetchingDelegate.logMessage("SALTEDGE POLLING CONNECTION FAILED")
                    fetchingDelegate.failedToFetch(connection: nil, connectionSecret: connectionSecret, message: error.localizedDescription, systemDescription: nil)
                }
            }
        }
    }
    
    private static func handleSuccessPollResponse(for connection: SEConnection, fetchingDelegate: SEConnectionFetchingDelegate) {
        switch connection.stage {
            
        case "interactive":
            fetchingDelegate.interactiveInputRequested(for: connection)
        case "finish":
            if let message = connection.failMessage {
                fetchingDelegate.failedToFetch(connection: connection, connectionSecret: nil, message: message, systemDescription: connection.lastAttemptResponse)
            } else {
                fetchingDelegate.successfullyFinishedFetching(connection: connection)
            }
        default:
            fetchingDelegate.connectionStageDidChange(connection)
            self.requestPolling(for: connection, fetchingDelegate: fetchingDelegate)
        }
    }
}
