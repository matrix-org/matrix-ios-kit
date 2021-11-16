//
// Copyright 2020 The Matrix.org Foundation C.I.C
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import DTCoreText

public extension DTHTMLElement {
    @objc func sanitize(with allowedHTMLTags: [String], bodyFont font: UIFont) {
        if let name = name, !allowedHTMLTags.contains(name) {
            
            // This is an unsupported tag.
            // Remove any attachments to fix rendering.
            textAttachment = nil
            
            // If the element has plan text content show that,
            // otherwise prevent the tag from displaying.
            if let stringContent = attributedString()?.string,
               !stringContent.isEmpty,
               let element = DTTextHTMLElement(name: nil, attributes: nil) {
                element.setText(stringContent)
                removeAllChildNodes()
                addChildNode(element)
                
                if let parent = parent() {
                    element.inheritAttributes(from: parent)
                } else {
                    fontDescriptor = DTCoreTextFontDescriptor()
                    fontDescriptor.fontFamily = font.familyName
                    fontDescriptor.fontName = font.fontName
                    fontDescriptor.pointSize = font.pointSize
                    paragraphStyle = DTCoreTextParagraphStyle.default()
                    
                    element.inheritAttributes(from: self)
                }
                element.interpretAttributes()
                
            } else if let parent = parent() {
                parent.removeChildNode(self)
            } else {
                didOutput = true
            }
            
        } else if let childNodes = childNodes as? [DTHTMLElement] {
            
            // This element is a supported tag, but it may contain children that aren't,
            // so santize all child nodes to ensure correct tags.
            for child in childNodes {
                child.sanitize(with: allowedHTMLTags, bodyFont: font)
            }
            
        }
    }
}
