//
//  StructOshi.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI
import UIKit

//class UIImageCropperViewController: UIViewController {
//    private let image: UIImage
//    private let aspectRatio: CGFloat?
//    private let onComplete: (UIImage?) -> Void
//    
//    private var imageView: UIImageView!
//    private var cropOverlayView: UIView!
//    private var cropRect: CGRect = CGRect.zero
//    
//    init(image: UIImage, aspectRatio: CGFloat?, onComplete: @escaping (UIImage?) -> Void) {
//        self.image = image
//        self.aspectRatio = aspectRatio
//        self.onComplete = onComplete
//        super.init(nibName: nil, bundle: nil)
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupUI()
//    }
//    
//    private func setupUI() {
//        view.backgroundColor = .black
//        
//        // イメージビューの設定
//        imageView = UIImageView(image: image)
//        imageView.contentMode = .scaleAspectFit
//        view.addSubview(imageView)
//        
//        // クロップオーバーレイの設定
//        cropOverlayView = UIView()
//        cropOverlayView.layer.borderColor = UIColor.white.cgColor
//        cropOverlayView.layer.borderWidth = 2.0
//        cropOverlayView.backgroundColor = .clear
//        view.addSubview(cropOverlayView)
//        
//        // ナビゲーションアイテムの追加
//        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
//        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
//        
//        // ジェスチャーの追加
//        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
//        cropOverlayView.addGestureRecognizer(panGesture)
//        
//        // レイアウト設定
//        imageView.translatesAutoresizingMaskIntoConstraints = false
//        cropOverlayView.translatesAutoresizingMaskIntoConstraints = false
//        
//        NSLayoutConstraint.activate([
//            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
//            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
//        ])
//    }
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        setupInitialCropRect()
//    }
//    
//    private func setupInitialCropRect() {
//        let imageFrame = imageView.frame
//        let imageSize = image.size
//        let imageViewSize = imageView.bounds.size
//        
//        // 画像の表示サイズを計算
//        let scale = min(imageViewSize.width / imageSize.width, imageViewSize.height / imageSize.height)
//        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
//        
//        // クロップ領域の初期サイズを設定
//        let cropWidth: CGFloat
//        let cropHeight: CGFloat
//        
//        if let ratio = aspectRatio {
//            cropWidth = min(scaledSize.width, scaledSize.height) * 0.8
//            cropHeight = cropWidth / ratio
//        } else {
//            cropWidth = scaledSize.width * 0.8
//            cropHeight = scaledSize.height * 0.8
//        }
//        
//        let x = imageFrame.midX - cropWidth / 2
//        let y = imageFrame.midY - cropHeight / 2
//        
//        cropRect = CGRect(x: x, y: y, width: cropWidth, height: cropHeight)
//        cropOverlayView.frame = cropRect
//    }
//    
//    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
//        guard let view = gesture.view else { return }
//        
//        let translation = gesture.translation(in: self.view)
//        
//        // クロップ領域を移動
//        view.center = CGPoint(x: view.center.x + translation.x,
//                              y: view.center.y + translation.y)
//        
//        // 画像の範囲内に収める
//        let imageFrame = imageView.frame
//        var newFrame = view.frame
//        
//        newFrame.origin.x = max(imageFrame.minX, min(newFrame.origin.x, imageFrame.maxX - newFrame.width))
//        newFrame.origin.y = max(imageFrame.minY, min(newFrame.origin.y, imageFrame.maxY - newFrame.height))
//        
//        view.frame = newFrame
//        cropRect = newFrame
//        
//        gesture.setTranslation(.zero, in: self.view)
//    }
//    
//    @objc private func cancelTapped() {
//        onComplete(nil)
//        dismiss(animated: true)
//    }
//    
//    @objc private func doneTapped() {
//        let croppedImage = cropImage()
//        onComplete(croppedImage)
//        dismiss(animated: true)
//    }
//    
//    private func cropImage() -> UIImage? {
//        // 画像の実際のサイズと表示サイズの比率を計算
//        let imageSize = image.size
//        let imageViewSize = imageView.bounds.size
//        let scale = max(imageSize.width / imageViewSize.width, imageSize.height / imageViewSize.height)
//        
//        // クロップ領域を画像の座標系に変換
//        let cropRectInImageCoordinates = CGRect(
//            x: (cropRect.origin.x - imageView.frame.origin.x) * scale,
//            y: (cropRect.origin.y - imageView.frame.origin.y) * scale,
//            width: cropRect.width * scale,
//            height: cropRect.height * scale
//        )
//        
//        // クロップ処理
//        guard let cgImage = image.cgImage?.cropping(to: cropRectInImageCoordinates) else {
//            return nil
//        }
//        
//        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
//    }
//}
//
//struct ImageCropperView: UIViewControllerRepresentable {
//    @Binding var image: UIImage?
//    @Binding var croppedImage: UIImage?
//    var aspectRatio: CGFloat? = nil
//    var onComplete: (UIImage?) -> Void
//    
//    func makeUIViewController(context: Context) -> UIViewController {
//        let cropperVC = UIImageCropperViewController(image: image ?? UIImage(),
//                                                     aspectRatio: aspectRatio,
//                                                     onComplete: onComplete)
//        return cropperVC
//    }
//    
//    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
//        // 更新処理は特に不要
//    }
//}
