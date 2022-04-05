//
//  File.swift
//  
//
//  Created by YuAo on 2022/4/6.
//

import Foundation
import SwiftUI

enum ToastType {
    case `default`
    case success
}

struct Toast {
    var title: String
    var type: ToastType
}

class ToastController: ObservableObject {
    @Published private(set) var shouldShowToast: Bool = false
    @Published private(set) var toast: Toast = Toast(title: "", type: .default)
    
    private var timer: Timer?
    
    func showToast(title: String, type: ToastType = .default, duration: TimeInterval = 2.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false, block: { [weak self] _ in
            self?.shouldShowToast = false
        })
        toast = Toast(title: title, type: type)
        shouldShowToast = true
    }
}

@available(macOS 11.0, *)
fileprivate struct ToastPresenter: ViewModifier {
    @ObservedObject var controller: ToastController
    
    @State private var showsToast: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        return content.overlay(VStack {
            if showsToast {
                Group {
                    switch controller.toast.type {
                    case .`default`:
                        Text(controller.toast.title)
                    case .success:
                        Label(title: {
                            Text(controller.toast.title)
                        }, icon: {
                            Image(systemName: "checkmark").foregroundColor(Color.green)
                        })
                    }
                }
                .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                .background(GeometryReader(content: { proxy in
                    RoundedRectangle(cornerRadius: proxy.size.height / 2).fill(colorScheme == .dark ? Color(.sRGB, white: 0.25, opacity: 1) : Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 0)
                }))
                .padding()
                .transition(.move(edge: .top))
            }
            Spacer()
        }).onReceive(controller.$shouldShowToast, perform: { value in
            withAnimation(.spring(), {
                self.showsToast = value
            })
        }).clipped()
    }
}

@available(macOS 11.0, *)
extension View {
    func presenter(for controller: ToastController) -> some View {
        self.modifier(ToastPresenter(controller: controller))
    }
}
