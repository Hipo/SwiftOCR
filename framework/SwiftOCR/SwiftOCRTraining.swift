//
//  SwiftOCRTraining.swift
//  SwiftOCR
//
//  Created by Nicolas Camenisch on 19.04.16.
//  Copyright © 2016 Nicolas Camenisch. All rights reserved.
//

import GPUImage

open class SwiftOCRTraining {

    fileprivate let ocrInstance        = SwiftOCR()
    
    //Training Variables
    fileprivate let trainingImageNames = ["TrainingBackground_1.png", "TrainingBackground_2.png", "TrainingBackground_3.png", "TrainingBackground_4.png"]
    open var trainingFontNames  = ["Arial Narrow", "Arial Narrow Bold"]

    public  init() {}
    
    /**
     Generates a training set for the neural network and uses that for training the neural network.
     */
    
    open  func trainWithCharSet(_ shouldContinue: @escaping (Float) -> Bool = {_ in return true}) {
        let numberOfTrainImages  = 500
        let numberOfTestImages   = 100
        let errorThreshold:Float = 2
        
        let trainData = generateRealisticCharSet(numberOfTrainImages/4)
        let testData  = generateRealisticCharSet(numberOfTestImages/4)
        
        let trainInputs  = trainData.map({return $0.0})
        let trainAnswers = trainData.map({return $0.1})
        let testInputs   =  testData.map({return $0.0})
        let testAnswers  =  testData.map({return $0.1})

        do {
            _ = try globalNetwork.train(inputs: trainInputs, answers: trainAnswers, testInputs: testInputs, testAnswers: testAnswers, errorThreshold: errorThreshold, shouldContinue: {error in shouldContinue(error)})
            saveOCR()
        } catch {
            print(error)
        }

    }

    /**
     Generates realistic images OCR and converts them to a float array.
     
     - Parameter size: The number of images to generate. This does **not** correspond to the the count of elements in the array that gets returned.
     - Returns:        An array containing the input and answers for the neural network.
     */
    
    fileprivate func generateRealisticCharSet(_ size: Int) -> [([Float],[Float])] {
        var trainingSet = [([Float],[Float])]()
        
        let randomCode: () -> String = {
            let randomCharacter: () -> String = {
                
                let charArray = Array(recognizableCharacters.characters)
                let randomDouble = Double(arc4random())/(Double(UINT32_MAX) + 1)
                let randomIndex  = Int(floor(randomDouble * Double(charArray.count)))
                return String(charArray[randomIndex])
            }
            
            var code = ""
            
            for _ in 0..<6 {
                code += randomCharacter()
            }
            
            return code
        }
        
        let numbers: () -> String = {
            return "1234567890"
        }
        
        let randomFloat: (CGFloat) -> CGFloat = { modi in
            return  (0 - modi) + CGFloat(arc4random()) / CGFloat(UINT32_MAX) * (modi * 2)
        }
        
        //Font
        
        let randomFontName: () -> String = {
            return "LexiconNo1-RomanA"
//            let randomDouble = Double(arc4random())/(Double(UINT32_MAX) + 1)
//            let randomIndex  = Int(floor(randomDouble * Double(self.trainingFontNames.count)))
//            return self.trainingFontNames[randomIndex]
        }
        
        let randomFont: () -> OCRFont = {
            let fontDescriptorWithNoFeatures = CTFontDescriptorCreateWithNameAndSize(
                randomFontName() as CFString, 45 + randomFloat(5))
            
            let defaultAllocator: CFAllocator = CFAllocatorGetDefault().takeRetainedValue()
            
            var numberSpacing = 17
            var numberSpacingType = 2
            
            let numberSpacingId = CFNumberCreate(defaultAllocator, CFNumberType.intType, &numberSpacing)
            let monospacedNumbersSelector = CFNumberCreate(defaultAllocator,
                                                           CFNumberType.intType,
                                                           &numberSpacingType)
            
            let fontDescriptor = CTFontDescriptorCreateCopyWithFeature(
                fontDescriptorWithNoFeatures,
                numberSpacingId!,
                monospacedNumbersSelector!)
            
            var numberCase = 21
            var numberCaseType = 1
            
            let numberCaseId = CFNumberCreate(defaultAllocator, CFNumberType.intType, &numberCase)
            let liningNumberCaseSelector = CFNumberCreate(defaultAllocator,
                                                          CFNumberType.intType,
                                                          &numberCaseType)
            
            let finalFontDescriptor = CTFontDescriptorCreateCopyWithFeature(
                fontDescriptor,
                numberCaseId!,
                liningNumberCaseSelector!)
            
            let font = CTFontCreateWithFontDescriptor(finalFontDescriptor,
                                                      45 + randomFloat(5),
                                                      nil) as OCRFont
            
            return font
        }
    
        let randomFontAttributes: () -> [NSAttributedStringKey: Any] = {
            
            let paragraphStyle       = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            paragraphStyle.alignment = NSTextAlignment.center
            
            return [.font: randomFont(),
                    .kern: CGFloat(8) as NSObject,
                    .foregroundColor: OCRColor(red: 27/255 + randomFloat(0.2), green: 16/255 + randomFloat(0.2), blue: 16/255 + randomFloat(0.2), alpha: 80/100 + randomFloat(0.2)),
                    .paragraphStyle: paragraphStyle]
        }
        
        //Image
        
        let randomImageName: () -> String = {
            let randomDouble = Double(arc4random())/(Double(UINT32_MAX) + 1)
            let randomIndex  = Int(floor(randomDouble * Double(self.trainingImageNames.count)))
            return self.trainingImageNames[randomIndex]
        }
        
        let randomImage: () -> OCRImage = {
            #if os(iOS)
                return OCRImage(named: randomImageName(), in: Bundle(for: SwiftOCR.self), compatibleWith: nil)!.copy() as! OCRImage
            #else
                return OCRImage(byReferencing: Bundle(for: SwiftOCR.self).url(forResource: randomImageName(), withExtension: nil, subdirectory: nil, localization: nil)!).copy() as! OCRImage
            #endif
        }
        
        #if os(iOS)
            let customImage: (String) -> OCRImage = { code in
                let randomImg = randomImage()
                
                UIGraphicsBeginImageContext(randomImg.size)
                randomImg.draw(in: CGRect(origin: CGPoint.zero, size: randomImg.size))
                
                NSString(string: code).draw(in: CGRect(origin: CGPoint(x: 0 + randomFloat(5), y: -15.5 + randomFloat(5)), size: randomImg.size), withAttributes: randomFontAttributes())
                
                let customImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                return customImage!
            }
        #else
            let customImage: (String) -> OCRImage = { code in
                let randomImg = randomImage()
                randomImg.lockFocus()
                
                randomImg.draw(in: CGRect(origin: CGPoint.zero, size: randomImg.size))
                
                NSString(string: code).draw(in: CGRect(origin: CGPoint(x: 0 + randomFloat(5), y: -15.5 + randomFloat(5)), size: randomImg.size), withAttributes: randomFontAttributes())
                
                randomImg.unlockFocus()

                return randomImg
            }
        #endif

        var saveIndex: Int = 0
        
        let numbersImage = customImage(numbers())
        
        //Distort Numbers Image
        let numbersTransformImage  = GPUImagePicture(image: numbersImage)
        let numbersTransformFilter = GPUImageTransformFilter()

//        var numbersAffineTransform = CGAffineTransform()
//
//        numbersAffineTransform.a  = 1.05 + (       CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.1 )
//        numbersAffineTransform.b  = 0    + (0.01 - CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.02)
//        numbersAffineTransform.c  = 0    + (0.03 - CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.06)
//        numbersAffineTransform.d  = 1.05 + (       CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.1 )
//
//        numbersTransformFilter.affineTransform = numbersAffineTransform
        numbersTransformImage?.addTarget(numbersTransformFilter)

        numbersTransformFilter.useNextFrameForImageCapture()
        numbersTransformImage?.processImage()

        var numbersTransformedImage:OCRImage? = numbersTransformFilter.imageFromCurrentFramebuffer(with: .up)

        while numbersTransformedImage == nil || numbersTransformedImage?.size == CGSize.zero {
            numbersTransformFilter.useNextFrameForImageCapture()
            numbersTransformImage?.processImage()
            numbersTransformedImage = numbersTransformFilter.imageFromCurrentFramebuffer(with: .up)
        }

        let numbersDistortedImage: NSImage = ocrInstance.preprocessImageForOCR(numbersTransformedImage!)
        
        saveImage(image: numbersDistortedImage, name: "chars")
        
        for _ in 0..<size {

            let code               = randomCode()
            let currentCustomImage = customImage(code)

            //Distort Image

            let transformImage  = GPUImagePicture(image: currentCustomImage)
            let transformFilter = GPUImageTransformFilter()

            var affineTransform = CGAffineTransform()

            affineTransform.a  = 1.05 + (       CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.1 )
            affineTransform.b  = 0    + (0.01 - CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.02)
            affineTransform.c  = 0    + (0.03 - CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.06)
            affineTransform.d  = 1.05 + (       CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.1 )

            transformFilter.affineTransform = affineTransform
            transformImage?.addTarget(transformFilter)

            transformFilter.useNextFrameForImageCapture()
            transformImage?.processImage()

            var transformedImage:OCRImage? = transformFilter.imageFromCurrentFramebuffer(with: .up)

            while transformedImage == nil || transformedImage?.size == CGSize.zero {
                transformFilter.useNextFrameForImageCapture()
                transformImage?.processImage()
                transformedImage = transformFilter.imageFromCurrentFramebuffer(with: .up)
            }

            let distortedImage = ocrInstance.preprocessImageForOCR(transformedImage!)

            //Generate Training set

            let blobs = ocrInstance.extractBlobs(distortedImage)

            if blobs.count == 6 {

                for blobIndex in 0..<blobs.count {

                    let blob = blobs[blobIndex]
                    let image: NSImage = blob.0

                    let index = code.index(code.startIndex, offsetBy: blobIndex)
                    let char = code[index]


                    let fileName = "\(char)_\(saveIndex)"

                    generateImageForSaving(image: image, fileName: fileName)

                    saveIndex += 1

                    let imageData = ocrInstance.convertImageToFloatArray(blob.0)

                    var imageAnswer = [Float](repeating: 0, count: recognizableCharacters.characters.count)
                    if let index = Array(recognizableCharacters.characters).index(of: Array(code.characters)[blobIndex]) {
                        imageAnswer[index] = 1
                    }

                    trainingSet.append((imageData,imageAnswer))
                }

            }


        }
        
        return trainingSet
    }
    
    private func generateImageForSaving(image: NSImage, fileName: String) {
        let size = image.size
        let maximumDimension: CGFloat = 20.0 // 2 point padding
        
        var minimumDimension: CGFloat = 20.0
        var scaledSize: CGSize = CGSize(width: maximumDimension, height: maximumDimension)
        
        if size.width > size.height {
            minimumDimension = (maximumDimension * size.height / size.width)
            scaledSize = CGSize(width: maximumDimension, height: minimumDimension)
        } else {
            minimumDimension = (maximumDimension * size.width / size.height)
            scaledSize = CGSize(width: minimumDimension, height: maximumDimension)
        }
        
        let resizedImage = image.resizeImage(width: scaledSize.width, scaledSize.height)
        let paddingImage = resizedImage.addPadding(4, withColor: NSColor.white)
        
        let resizedIconImage = paddingImage.resizeImage(width: paddingImage.size.width / 2,
                                                        paddingImage.size.height / 2)
        
        saveImage(image: resizedIconImage,
                  name: fileName)
    }
    
    private func saveImage(image: NSImage,
                           name: String) {
        guard let documentURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask).first else {
                return
        }
        
        let fileName = "\(name).png"
        
        let folderURL = documentURL.appendingPathComponent("FilamentDataset")
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: folderURL,
                    withIntermediateDirectories: false,
                    attributes: nil)
            } catch  {
                print("cannot create directory - folder Exists?")
            }
        }
        
        let url = folderURL.appendingPathComponent(fileName)
        do {
            try image.savePngTo(url: url)
        }
        catch {
            print("error saving file")
        }
    }
    
    /**
     Converts images to a float array for training.
     
     - Parameter images: The number of images to generate. This does **not** correspond to the the count of elements in the array that gets returned.
     - Parameter withNumberOfDistortions: How many distorted images should get generated from each input image.
     - Returns:        An array containing the input and answers for the neural network.
     */
    
    fileprivate func generateCharSetFromImages(_ images: [(image: OCRImage, characters: [Character])], withNumberOfDistortions distortions: Int) -> [([Float],[Float])] {
        
        var trainingSet = [([Float],[Float])]()
        
        let randomFloat: (CGFloat) -> CGFloat = { modi in
            return  (0 - modi) + CGFloat(arc4random()) / CGFloat(UINT32_MAX) * (modi * 2)
        }
        
        for (image, characters) in images {
            
            var imagesToExtractBlobsFrom = [OCRImage]()
            
            //Original
            imagesToExtractBlobsFrom.append(ocrInstance.preprocessImageForOCR(image))
            
            //Distortions
            for _ in 0..<distortions {
                let transformImage  = GPUImagePicture(image: image)
                let transformFilter = GPUImageTransformFilter()
                
                var affineTransform = CGAffineTransform()
                
                affineTransform.a  = 1.05 + (       CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.1 )
                affineTransform.b  = 0    + (0.01 - CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.02)
                affineTransform.c  = 0    + (0.03 - CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.06)
                affineTransform.d  = 1.05 + (       CGFloat(arc4random())/CGFloat(UINT32_MAX) * 0.1 )
                
                affineTransform.a  = 1.05 + (randomFloat(0.05) + 0.05)
                affineTransform.b  = 0    + (randomFloat(0.01))
                affineTransform.c  = 0    + (randomFloat(0.03))
                affineTransform.d  = 1.05 + (randomFloat(0.1) + 0.05)
                
                transformFilter.affineTransform = affineTransform
                transformImage?.addTarget(transformFilter)
                
                transformFilter.useNextFrameForImageCapture()
                transformImage?.processImage()
                
                var transformedImage:OCRImage? = transformFilter.imageFromCurrentFramebuffer(with: .up)
                
                while transformedImage == nil || transformedImage?.size == CGSize.zero {
                    transformFilter.useNextFrameForImageCapture()
                    transformImage?.processImage()
                    transformedImage = transformFilter.imageFromCurrentFramebuffer(with: .up)
                }
                
                let distortedImage = ocrInstance.preprocessImageForOCR(transformedImage!)
                imagesToExtractBlobsFrom.append(distortedImage)
            }
            
            //Convert to data
            
            for preprocessedImage in imagesToExtractBlobsFrom {
                
                let blobs = ocrInstance.extractBlobs(preprocessedImage)
                
                if blobs.count == characters.count {
                    
                    for (blobIndex, blob) in blobs.enumerated() {
                        let imageData = ocrInstance.convertImageToFloatArray(blob.0)
                        
                        var imageAnswer = [Float](repeating: 0, count: recognizableCharacters.characters.count)
                        if let index = Array(recognizableCharacters.characters).index(of: characters[blobIndex]) {
                            imageAnswer[index] = 1
                        }
                        
                        trainingSet.append((imageData,imageAnswer))
                    }
                }
            }
            
            
        }
        
        trainingSet.shuffle()
        
        return trainingSet
    }

    /**
     Saves the neural network to a file.
     */
    
    open   func saveOCR() {
        //Set this path to the location of your OCR-Network file.
        let path = NSString(string:"~/Desktop/OCR-Network").expandingTildeInPath
        globalNetwork.writeToFile(URL(string: "file://\(path)")!)
    }
    
    /**
     Use this method to test the neural network.
     */
    
    open   func testOCR(_ completionHandler: (Double) -> Void) {
        let testData  = generateRealisticCharSet(recognizableCharacters.characters.count)
        
        var correctCount = 0
        var totalCount   = 0
        
        for i in testData {
            totalCount += 1
            do {
                let networkResult = try globalNetwork.update(inputs: i.0)
                
                let input      = Array(recognizableCharacters.characters)[i.1.index(of: 1)!]
                let recognized = Array(recognizableCharacters.characters)[networkResult.index(of: networkResult.max() ?? 0) ?? 0]
                
                print(input, recognized)
                
                if input == recognized {
                    correctCount += 1
                }
                
            } catch {
                
            }
        }
        
        completionHandler(Double(correctCount) / Double(totalCount))
        
    }
    
}
