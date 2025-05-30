// ================================================================================================
//  RXMLElement.m
//  Fast processing of XML files
//
// ================================================================================================
//  Created by John Blanco on 9/23/11.
//  Version 1.4
//  
//  Copyright (c) 2011 John Blanco
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
// ================================================================================================
//

#import "RXMLElement.h"

@implementation RXMLDocHolder

- (instancetype)initWithDocPtr:(xmlDocPtr)doc {
    if ((self = [super init])) {
        doc_ = doc;
    }

    return self;
}

- (void)dealloc {
    if (doc_ != nil) {
        xmlFreeDoc(doc_);
    }
}

- (xmlDocPtr)doc {
    return doc_;
}

@end

@implementation RXMLElement

- (instancetype)initFromXMLString:(NSString *)xmlString encoding:(NSStringEncoding)encoding {
    return [self initFromXMLData:[xmlString dataUsingEncoding:encoding]];
}

- (instancetype)initFromXMLFilePath:(NSString *)fullPath {
    return [self initFromXMLData:[NSData dataWithContentsOfFile:fullPath]];
}

- (instancetype)initFromXMLFile:(NSString *)filename {
    NSString *fullPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:filename];
    return [self initFromXMLFilePath:fullPath];
}

- (instancetype)initFromXMLFile:(NSString *)filename fileExtension:(NSString *)extension {
    NSString *fullPath = [[NSBundle mainBundle] pathForResource:filename ofType:extension];
    return [self initFromXMLData:[NSData dataWithContentsOfFile:fullPath]];
}

- (instancetype)initFromURL:(NSURL *)url {
    return [self initFromXMLData:[NSData dataWithContentsOfURL:url]];
}

- (instancetype)initFromXMLData:(NSData *)data {
    if ((self = [super init])) {
        xmlDocPtr doc = xmlReadMemory([data bytes], (int)[data length], "", nil, XML_PARSE_RECOVER|XML_PARSE_NOENT);
        self.xmlDoc = [[RXMLDocHolder alloc] initWithDocPtr:doc];
        
        if ([self isValid]) {
            node_ = xmlDocGetRootElement(doc);
            
            if (!node_) {
                self.xmlDoc = nil;
            }
        }
    }
    
    return self;    
}

- (instancetype)initFromXMLDoc:(RXMLDocHolder *)doc node:(xmlNodePtr)node {
    if ((self = [super init])) {
        self.xmlDoc = doc;
        node_ = node;
    }
    
    return self;        
}

- (instancetype)initFromHTMLString:(NSString *)xmlString encoding:(NSStringEncoding)encoding {
    return [self initFromHTMLData:[xmlString dataUsingEncoding:encoding]];
}

- (instancetype)initFromHTMLFile:(NSString *)filename {
    NSString *fullPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:filename];
    return [self initFromHTMLData:[NSData dataWithContentsOfFile:fullPath]];
}

- (instancetype)initFromHTMLFile:(NSString *)filename fileExtension:(NSString*)extension {
    NSString *fullPath = [[NSBundle mainBundle] pathForResource:filename ofType:extension];
    return [self initFromHTMLData:[NSData dataWithContentsOfFile:fullPath]];
}

- (instancetype)initFromHTMLFilePath:(NSString *)fullPath {
    return [self initFromHTMLData:[NSData dataWithContentsOfFile:fullPath]];

}

- (instancetype)initFromHTMLData:(NSData *)data {
    if ((self = [super init])) {
        xmlDocPtr doc = htmlReadMemory([data bytes], (int)[data length], "", nil, HTML_PARSE_NOWARNING | HTML_PARSE_NOERROR);
        self.xmlDoc = [[RXMLDocHolder alloc] initWithDocPtr:doc];
        
        if ([self isValid]) {
            node_ = xmlDocGetRootElement(doc);
            
            if (!node_) {
                self.xmlDoc = nil;
            }
        }
    }
    return self;
}


// Copy the RaptureXML element
// (calling copy will call this method automatically with the default zone)
-(id)copyWithZone:(NSZone *)zone{
    RXMLElement* new_element = [[RXMLElement alloc] init];
    new_element->node_ = node_;
    new_element.xmlDoc = self.xmlDoc;
    return new_element;
}

+ (instancetype)elementFromXMLString:(NSString *)attributeXML_ encoding:(NSStringEncoding)encoding {
    return [[RXMLElement alloc] initFromXMLString:attributeXML_ encoding:encoding];    
}

+ (instancetype)elementFromXMLFilePath:(NSString *)fullPath {
    return [[RXMLElement alloc] initFromXMLFilePath:fullPath];
}

+ (instancetype)elementFromXMLFile:(NSString *)filename {
    return [[RXMLElement alloc] initFromXMLFile:filename];    
}

+ (instancetype)elementFromXMLFilename:(NSString *)filename fileExtension:(NSString *)extension {
    return [[RXMLElement alloc] initFromXMLFile:filename fileExtension:extension];
}

+ (instancetype)elementFromURL:(NSURL *)url {
    return [[RXMLElement alloc] initFromURL:url];
}

+ (instancetype)elementFromXMLData:(NSData *)data {
    return [[RXMLElement alloc] initFromXMLData:data];
}

+ (instancetype)elementFromXMLDoc:(RXMLDocHolder *)doc node:(xmlNodePtr)node {
    return [[RXMLElement alloc] initFromXMLDoc:doc node:node];
}

- (NSString *)description {
    return [self text];
}

+ (instancetype)elementFromHTMLString:(NSString *)xmlString encoding:(NSStringEncoding)encoding {
    return [[RXMLElement alloc] initFromHTMLString:xmlString encoding:encoding];
}

+ (instancetype)elementFromHTMLFile:(NSString *)filename {
    return [[RXMLElement alloc] initFromHTMLFile:filename];
}

+ (instancetype)elementFromHTMLFile:(NSString *)filename fileExtension:(NSString*)extension {
    return [[RXMLElement alloc] initFromHTMLFile:filename fileExtension:extension];
}

+ (instancetype)elementFromHTMLFilePath:(NSString *)fullPath {
    return [[RXMLElement alloc] initFromHTMLFilePath:fullPath];
}

+ (instancetype)elementFromHTMLData:(NSData *)data {
    return [[RXMLElement alloc] initFromHTMLData:data];
}

#pragma mark -

- (NSString *)tag {
    if (node_) {
        return [NSString stringWithUTF8String:(const char *)node_->name];
    } else {
        return nil;
    }
}

- (NSString *)text {
    xmlChar *key = xmlNodeGetContent(node_);
    NSString *text = (key ? [NSString stringWithUTF8String:(const char *)key] : @"");
    xmlFree(key);

    return text;
}

- (NSString *)xml {
    xmlBufferPtr buffer = xmlBufferCreate();
    xmlNodeDump(buffer, node_->doc, node_, 0, false);
    NSString *text = [NSString stringWithUTF8String:(const char *)xmlBufferContent(buffer)];
    xmlBufferFree(buffer);
    return text;
}

- (NSString *)innerXml {
    NSMutableString* innerXml = [NSMutableString string];
    xmlNodePtr cur = node_->children;
    
    while (cur != nil) {
        if (cur->type == XML_TEXT_NODE) {
            xmlChar *key = xmlNodeGetContent(cur);
            NSString *text = (key ? [NSString stringWithUTF8String:(const char *)key] : @"");
            xmlFree(key);
            [innerXml appendString:text];
        } else {
            xmlBufferPtr buffer = xmlBufferCreate();
            xmlNodeDump(buffer, node_->doc, cur, 0, false);
            NSString *text = [NSString stringWithUTF8String:(const char *)xmlBufferContent(buffer)];
            xmlBufferFree(buffer);
            [innerXml appendString:text];            
        }
        cur = cur->next;
    }

    return innerXml;
}

- (NSInteger)textAsInt {
    return [self.text intValue];
}

- (double)textAsDouble {
    return [self.text doubleValue];
}

- (NSString *)attribute:(NSString *)attName {
    NSString *ret = nil;
    const unsigned char *attCStr = xmlGetProp(node_, (const xmlChar *)[attName cStringUsingEncoding:NSUTF8StringEncoding]);        
    
    if (attCStr) {
        ret = [NSString stringWithUTF8String:(const char *)attCStr];
        xmlFree((void *)attCStr);
    }
    
    return ret;
}

- (NSString *)attribute:(NSString *)attName inNamespace:(NSString *)ns {
    const unsigned char *attCStr = xmlGetNsProp(node_, (const xmlChar *)[attName cStringUsingEncoding:NSUTF8StringEncoding], (const xmlChar *)[ns cStringUsingEncoding:NSUTF8StringEncoding]);

    if (attCStr) {
        return [NSString stringWithUTF8String:(const char *)attCStr];
    }
    
    return nil;
}

- (NSArray *)attributeNames {
    NSMutableArray *names = [[NSMutableArray alloc] init];

    for(xmlAttrPtr attr = node_->properties; attr != nil; attr = attr->next) {
        [names addObject:[[NSString alloc] initWithCString:(const char *)attr->name encoding:NSUTF8StringEncoding]];
    }

    return names;
}

- (NSInteger)attributeAsInt:(NSString *)attName {
    return [[self attribute:attName] intValue];
}

- (NSInteger)attributeAsInt:(NSString *)attName inNamespace:(NSString *)ns {
    return [[self attribute:attName inNamespace:ns] intValue];
}

- (double)attributeAsDouble:(NSString *)attName {
    return [[self attribute:attName] doubleValue];
}

- (double)attributeAsDouble:(NSString *)attName inNamespace:(NSString *)ns {
    return [[self attribute:attName inNamespace:ns] doubleValue];
}

- (BOOL)isValid {
    return (self.xmlDoc != nil);
}

#pragma mark -

- (RXMLElement *)child:(NSString *)tag {
    NSArray *components = [tag componentsSeparatedByString:@"."];
    xmlNodePtr cur = node_;
	
	if (!cur) return nil;
    
    // navigate down
    for (NSString *itag in components) {
        const xmlChar *tagC = (const xmlChar *)[itag cStringUsingEncoding:NSUTF8StringEncoding];

        if ([itag isEqualToString:@"*"]) {
            cur = cur->children;
            
            while (cur != nil && cur->type != XML_ELEMENT_NODE) {
                cur = cur->next;
            }
        } else {
            cur = cur->children;
            while (cur != nil) {
                if (cur->type == XML_ELEMENT_NODE && !xmlStrcmp(cur->name, tagC)) {
                    break;
                }
                
                cur = cur->next;
            }
        }
        
        if (!cur) {
            break;
        }
    }
    
    if (cur) {
        return [RXMLElement elementFromXMLDoc:self.xmlDoc node:cur];
    }
  
    return nil;
}

- (RXMLElement *)child:(NSString *)tag inNamespace:(NSString *)ns {
    NSArray *components = [tag componentsSeparatedByString:@"."];
    xmlNodePtr cur = node_;
    const xmlChar *namespaceC = (const xmlChar *)[ns cStringUsingEncoding:NSUTF8StringEncoding];
    
    // navigate down
    for (NSString *itag in components) {
        const xmlChar *tagC = (const xmlChar *)[itag cStringUsingEncoding:NSUTF8StringEncoding];
        
        if ([itag isEqualToString:@"*"]) {
            cur = cur->children;
            
            while (cur != nil && cur->type != XML_ELEMENT_NODE && !xmlStrcmp(cur->ns->href, namespaceC)) {
                cur = cur->next;
            }
        } else {
            cur = cur->children;
            while (cur != nil) {
                if (cur->ns != nil) {
                    if (cur->type == XML_ELEMENT_NODE &&
                        !xmlStrcmp(cur->name, tagC) &&
                        !xmlStrcmp(cur->ns->href, namespaceC)) {
                        break;
                    }
                } else {
                    if (cur->type == XML_ELEMENT_NODE &&
                        !xmlStrcmp(cur->name, tagC) &&
                        !xmlStrcmp(namespaceC, nil)) {
                        break;
                    }
                }

                
                cur = cur->next;
            }
        }
        
        if (!cur) {
            break;
        }
    }
    
    if (cur) {
        return [RXMLElement elementFromXMLDoc:self.xmlDoc node:cur];
    }
    
    return nil;
}

- (NSArray *)children:(NSString *)tag {
    const xmlChar *tagC = (const xmlChar *)[tag cStringUsingEncoding:NSUTF8StringEncoding];
    NSMutableArray *children = [NSMutableArray array];
    xmlNodePtr cur = node_->children;

    while (cur != nil) {
        if (cur->type == XML_ELEMENT_NODE && !xmlStrcmp(cur->name, tagC)) {
            [children addObject:[RXMLElement elementFromXMLDoc:self.xmlDoc node:cur]];
        }
        
        cur = cur->next;
    }
    
    return [children copy];
}

- (NSArray *)children:(NSString *)tag inNamespace:(NSString *)ns {
    const xmlChar *tagC = (const xmlChar *)[tag cStringUsingEncoding:NSUTF8StringEncoding];
    const xmlChar *namespaceC = (const xmlChar *)[ns cStringUsingEncoding:NSUTF8StringEncoding];
    NSMutableArray *children = [NSMutableArray array];
    xmlNodePtr cur = node_->children;
    
    while (cur != nil) {
        if (cur->type == XML_ELEMENT_NODE && !xmlStrcmp(cur->name, tagC) && !xmlStrcmp(cur->ns->href, namespaceC)) {
            [children addObject:[RXMLElement elementFromXMLDoc:self.xmlDoc node:cur]];
        }
        
        cur = cur->next;
    }
    
    return [children copy];
}

- (NSArray *)childrenWithRootXPath:(NSString *)xpath {
    // check for a query
    if (!xpath) {
        return [NSArray array];
    }

    xmlXPathContextPtr context = xmlXPathNewContext([self.xmlDoc doc]);
    
    if (context == NULL) {
		return nil;
    }
    
    xmlXPathObjectPtr object = xmlXPathEvalExpression((xmlChar *)[xpath cStringUsingEncoding:NSUTF8StringEncoding], context);
    if(object == NULL) {
		return nil;
    }
    
	xmlNodeSetPtr nodes = object->nodesetval;
	if (nodes == NULL) {
		return nil;
	}
    
	NSMutableArray *resultNodes = [NSMutableArray array];
    
    for (NSInteger i = 0; i < nodes->nodeNr; i++) {
		RXMLElement *element = [RXMLElement elementFromXMLDoc:self.xmlDoc node:nodes->nodeTab[i]];
        
		if (element != NULL) {
			[resultNodes addObject:element];
		}
	}
    
    xmlXPathFreeObject(object);
    xmlXPathFreeContext(context); 
    
    return resultNodes;
}

#pragma mark -

- (BOOL)iterate:(NSString *)query usingBlock:(void (^)(RXMLElement *element, BOOL *stop))blk {
    // check for a query
    if (!query) {
        return NO;
    }
    
    NSArray *components = [query componentsSeparatedByString:@"."];
    xmlNodePtr cur = node_;

    // navigate down
    for (NSInteger i=0; i < components.count; ++i) {
        NSString *iTagName = [components objectAtIndex:i];
        
        if ([iTagName isEqualToString:@"*"]) {
            cur = cur->children;
 
            // different behavior depending on if this is the end of the query or midstream
            if (i < (components.count - 1) && cur != nil) {
                // midstream
                do {
                    if (cur->type == XML_ELEMENT_NODE) {
                        RXMLElement *element = [RXMLElement elementFromXMLDoc:self.xmlDoc node:cur];
                        NSString *restOfQuery = [[components subarrayWithRange:NSMakeRange(i + 1, components.count - i - 1)] componentsJoinedByString:@"."];
                        [element iterate:restOfQuery usingBlock:blk];
                    }
                    
                    cur = cur->next;
                } while (cur != nil);
                    
            }
        } else {
            const xmlChar *tagNameC = (const xmlChar *)[iTagName cStringUsingEncoding:NSUTF8StringEncoding];

            cur = cur->children;
            while (cur != nil) {
                if (cur->type == XML_ELEMENT_NODE && !xmlStrcmp(cur->name, tagNameC)) {
                    break;
                }
                
                cur = cur->next;
            }
        }

        if (!cur) {
            break;
        }
    }

    if (cur) {
        // enumerate
        NSString *childTagName = [components lastObject];
        
        do {
            if (cur->type == XML_ELEMENT_NODE) {
                RXMLElement *element = [RXMLElement elementFromXMLDoc:self.xmlDoc node:cur];
                BOOL stop = NO;
                blk(element, &stop);
                if (stop) return NO;
            }
            
            if ([childTagName isEqualToString:@"*"]) {
                cur = cur->next;
            } else {
                const xmlChar *tagNameC = (const xmlChar *)[childTagName cStringUsingEncoding:NSUTF8StringEncoding];

                while ((cur = cur->next)) {
                    if (cur->type == XML_ELEMENT_NODE && !xmlStrcmp(cur->name, tagNameC)) {
                        break;
                    }                    
                }
            }
        } while (cur);
    }
    
    return YES;
}

- (BOOL)iterateWithRootXPath:(NSString *)xpath usingBlock:(void (^)(RXMLElement *element, BOOL *stop))blk {
    NSArray *children = [self childrenWithRootXPath:xpath];
    return [self iterateElements:children usingBlock:blk];
}

- (BOOL)iterateElements:(NSArray *)elements usingBlock:(void (^)(RXMLElement *element, BOOL *stop))blk {
    for (RXMLElement *iElement in elements) {
        BOOL stop = NO;
        blk(iElement, &stop);
        if (stop) return NO;
    }
    return YES;
}

@end
