import Foundation

public final class Subscriber<T, E> {
    fileprivate var next: ((T) -> Void)!
    fileprivate var error: ((E) -> Void)!
    fileprivate var completed: (() -> Void)!
    
    fileprivate var lock = pthread_mutex_t()
    fileprivate var terminated = false
    internal var disposable: Disposable!
    
    public init(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) {
        self.next = next
        self.error = error
        self.completed = completed
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
        var freeDisposable: Disposable?
        pthread_mutex_lock(&self.lock)
        if let disposable = self.disposable {
            freeDisposable = disposable
            self.disposable = nil
        }
        pthread_mutex_unlock(&self.lock)
        freeDisposable = nil
        
        pthread_mutex_destroy(&self.lock)
    }
    
    internal func assignDisposable(_ disposable: Disposable) {
        var dispose = false
        pthread_mutex_lock(&self.lock)
        if self.terminated {
            dispose = true
        } else {
            self.disposable = disposable
        }
        pthread_mutex_unlock(&self.lock)
        
        if dispose {
            disposable.dispose()
        }
    }
    
    internal func markTerminatedWithoutDisposal() {
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            self.terminated = true
            self.next = nil
            self.error = nil
            self.completed = nil
        }
        pthread_mutex_unlock(&self.lock)
    }
    
    public func putNext(_ next: T) {
        var action: ((T) -> Void)! = nil
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.next
        }
        pthread_mutex_unlock(&self.lock)
        
        if action != nil {
            action(next)
        }
    }
    
    public func putError(_ error: E) {
        var action: ((E) -> Void)! = nil
        
        var disposeDisposable: Disposable?
        
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.error
            self.next = nil
            self.error = nil
            self.completed = nil;
            self.terminated = true
            disposeDisposable = self.disposable
            self.disposable = nil
            
        }
        pthread_mutex_unlock(&self.lock)
        
        if action != nil {
            action(error)
        }
        
        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
        }
    }
    
    public func putCompletion() {
        var action: (() -> Void)! = nil
        
        var disposeDisposable: Disposable? = nil
        
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.completed
            self.next = nil
            self.error = nil
            self.completed = nil
            self.terminated = true
            
            disposeDisposable = self.disposable
            self.disposable = nil
        }
        pthread_mutex_unlock(&self.lock)
        
        if action != nil {
            action()
        }
        
        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
        }
    }
}
