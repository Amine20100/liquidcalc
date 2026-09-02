//
//  UpdateNotificationBannerView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Non-Intrusive Floating Frosted Glass Update Notification Banner
//

import SwiftUI

public struct UpdateNotificationBannerView: View {
    public let release: GitHubRelease
    @Bindable public var updateManager: AppUpdateManager
    
    @State private var dragOffset: CGFloat = 0
    @State private var isPulsingGlow: Bool = false
    
    public init(release: GitHubRelease, updateManager: AppUpdateManager = .shared) {
        self.release = release
        self.updateManager = updateManager
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Neon Pulsing Update Icon
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(isPulsingGlow ? 0.35 : 0.15))
                    .frame(width: 38, height: 38)
                    .scaleEffect(isPulsingGlow ? 1.15 : 0.95)
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan, Color(red: 0.0, green: 1.0, blue: 0.64)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Version and Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("New Update")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(release.tagName)
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.25))
                        .foregroundColor(.cyan)
                        .clipShape(Capsule())
                }
                
                Text(release.displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 4)
            
            // View / Update Action Button
            Button(action: {
                SoundAndHapticManager.shared.triggerHaptic(.medium)
                updateManager.showUpdateSheet = true
                updateManager.hasPendingUpdateBanner = false
            }) {
                Text("View")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color(red: 0.0, green: 1.0, blue: 0.64)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.cyan.opacity(0.4), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            // Close / Dismiss Button
            Button(action: {
                SoundAndHapticManager.shared.triggerHaptic(.light)
                updateManager.dismissBanner()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.88)
                
                LinearGradient(
                    colors: [Color.cyan.opacity(0.12), Color.purple.opacity(0.06), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.6), Color.white.opacity(0.15), Color.cyan.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 8)
        .shadow(color: Color.cyan.opacity(0.2), radius: 8, x: 0, y: 2)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -25 {
                        updateManager.dismissBanner()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsingGlow = true
            }
        }
    }
}
