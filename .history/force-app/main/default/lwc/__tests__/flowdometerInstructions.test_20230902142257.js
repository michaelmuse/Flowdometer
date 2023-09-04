// force-app/main/default/lwc/__tests__/flowdometerInstructions.test.js
import { createElement } from 'lwc';
import FlowdometerInstructions from 'c/flowdometerInstructions';
import MockedModal from '../__mocks__/modal.mock.js';  // Import your mock

let element;  // Declare it once here at the top

// Use the mock class here
jest.mock('c/modal', () => {
  return {
    __esModule: true,
    default: MockedModal,  // Use the imported mock class
  };
}, { virtual: true });

describe('c-flowdometer-instructions', () => {
  beforeEach(() => {
    element = createElement('c-flowdometer-instructions', { is: FlowdometerInstructions });
    document.body.appendChild(element);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it('should render the correct number of steps', () => {
    return Promise.resolve().then(() => {
      const listItemEls = element.shadowRoot.querySelectorAll('li');
      expect(listItemEls.length).toBe(element.steps.length);
    });
  });

  it('should mark the first step as completed when clicked', () => {
    return Promise.resolve().then(() => {
      const listItemEls = element.shadowRoot.querySelectorAll('li');
      listItemEls[0].click();
      expect(element.steps[0].completed).toBe(true);
    });
  });
});

// When I run these tests, I get the following failures:
    // PS F:\Muse Operations Drive\Projects\Flowdometer> npm run test
    // >>

    // > Flowdometer@1.0.0 test
    // > npm run test:unit


    // > Flowdometer@1.0.0 test:unit
    // > sfdx-lwc-jest -- --config jest.config.js

    //  FAIL  force-app/main/default/lwc/__tests__/modal.mock.js
    //   ● Test suite failed to run
                                                                                                                
    //     TypeError: Class extends value undefined is not a constructor or null                                    
                                                                                                                
    //       2 | import { LightningElement } from 'lwc';                                                            
    //       3 |                                                                                                    
    //     > 4 | export default class MockedModal extends LightningElement {                                        
    //         |                                          ^                                                         
    //       5 |   name = 'mockedModal';
    //       6 |   slots = { content: [] };
    //       7 |   addEventListener = jest.fn((event, callback) => {

    //       at Object.LightningElement (force-app/main/default/lwc/__tests__/modal.mock.js:4:42)

    //  FAIL  force-app/main/default/lwc/__tests__/modal.test.js
    //   ● Test suite failed to run                                                                                 
                                                                                                                
    //     TypeError: Class extends value undefined is not a constructor or null                                    
                                                                                                                
    //       2 | import { LightningElement, api, track } from 'lwc';                                                
    //       3 |                                                                                                    
    //     > 4 | export default class MockedModal extends LightningElement {                                        
    //         |                                          ^                                                         
    //       5 |   // Emulating public properties
    //       6 |   @api publicPropertyExample;
    //       7 |

    //       at Object.LightningElement (force-app/main/default/lwc/__mocks__/modal.js:4:42)
    //       at Object.require (force-app/main/default/lwc/__tests__/modal.test.js:3:1)

    //  FAIL  force-app/main/default/lwc/__tests__/flowdometerInstructions.test.js
    //   ● Test suite failed to run

    //     ReferenceError: F:\Muse Operations Drive\Projects\Flowdometer\force-app\main\default\lwc\__tests__\flowdometerInstructions.test.js: The module factory of `jest.mock()` is not allowed to reference any out-of-scope variables.
    //     Invalid variable access: _registerDecorators
    //     Allowed objects: AbortController, AbortSignal, AggregateError, Array, ArrayBuffer, Atomics, BigInt, BigInt64Array, BigUint64Array, Blob, Boolean, BroadcastChannel, Buffer, ByteLengthQueuingStrategy, CompressionStream, CountQueuingStrategy, Crypto, CryptoKey, CustomEvent, DOMException, DataView, Date, DecompressionStream, Error, EvalError, Event, EventTarget, File, FinalizationRegistry, Float32Array, Float64Array, FormData, Function, Generator, GeneratorFunction, Headers, Infinity, Int16Array, Int32Array, Int8Array, InternalError, Intl, JSON, Map, Math, MessageChannel, MessageEvent, MessagePort, NaN, Number, Object, Performance, PerformanceEntry, PerformanceMark, PerformanceMeasure, PerformanceObserver, PerformanceObserverEntryList, PerformanceResourceTiming, Promise, Proxy, RangeError, ReadableByteStreamController, ReadableStream, ReadableStreamBYOBReader, ReadableStreamBYOBRequest, ReadableStreamDefaultController, ReadableStreamDefaultReader, ReferenceError, Reflect, RegExp, Request, Response, Set, SharedArrayBuffer, String, SubtleCrypto, Symbol, SyntaxError, TextDecoder, TextDecoderStream, TextEncoder, TextEncoderStream, TransformStream, TransformStreamDefaultController, TypeError, URIError, URL, URLSearchParams, Uint16Array, Uint32Array, Uint8Array, Uint8ClampedArray, WeakMap, WeakRef, WeakSet, WebAssembly, WritableStream, WritableStreamDefaultController, WritableStreamDefaultWriter, __dirname, __filename, arguments, atob, btoa, clearImmediate, clearInterval, clearTimeout, console, crypto, decodeURI, decodeURIComponent, encodeURI, encodeURIComponent, escape, eval, expect, exports, fetch, global, globalThis, isFinite, isNaN, jest, module, parseFloat, parseInt, performance, process, queueMicrotask, require, setImmediate, setInterval, setTimeout, structuredClone, undefined, unescape.
    //     Note: This is a precaution to guard against uninitialized mock variables. If it is ensured that the mock is required lazily, variable names prefixed with `mock` (case insensitive) are permitted.

    //       11 |   return {
    //       12 |     __esModule: true,
    //     > 13 |     default: _registerDecorators(class MockedModal extends LightningElement {
    //          |              ^^^^^^^^^^^^^^^^^^^
    //       14 |       constructor(...args) {
    //       15 |         super(...args);
    //       16 |         this.name = 'mockedModal';

    //       at File.buildCodeFrameError (node_modules/@salesforce/sfdx-lwc-jest/node_modules/@babel/core/src/transformation/file/file.ts:279:12)
    //       at NodePath.buildError [as buildCodeFrameError] (node_modules/@babel/traverse/src/path/index.ts:136:21)
    //       at call (node_modules/@babel/traverse/src/visitors.ts:292:14)
    //       at NodePath.call [as _call] (node_modules/@babel/traverse/src/path/context.ts:35:20)
    //       at NodePath._call [as call] (node_modules/@babel/traverse/src/path/context.ts:20:17)
    //       at NodePath.call [as visit] (node_modules/@babel/traverse/src/path/context.ts:94:31)
    //       at TraversalContext.visit [as visitQueue] (node_modules/@babel/traverse/src/context.ts:144:16)
    //       at TraversalContext.visitQueue [as visitMultiple] (node_modules/@babel/traverse/src/context.ts:98:17)  
    //       at TraversalContext.visitMultiple [as visit] (node_modules/@babel/traverse/src/context.ts:174:19)      
    //       at visit (node_modules/@babel/traverse/src/traverse-node.ts:40:17)
    //       at NodePath.visit (node_modules/@babel/traverse/src/path/context.ts:101:33)
    //       at TraversalContext.visit [as visitQueue] (node_modules/@babel/traverse/src/context.ts:144:16)
    //       at TraversalContext.visitQueue [as visitSingle] (node_modules/@babel/traverse/src/context.ts:108:19)   
    //       at TraversalContext.visitSingle [as visit] (node_modules/@babel/traverse/src/context.ts:176:19)        
    //       at visit (node_modules/@babel/traverse/src/traverse-node.ts:40:17)
    //       at traverse (node_modules/@babel/traverse/src/index.ts:82:15)
    //           at transformFile.next (<anonymous>)
    //           at run.next (<anonymous>)
    //           at transform.next (<anonymous>)
    //       at evaluateSync (node_modules/gensync/index.js:251:28)
    //       at sync (node_modules/gensync/index.js:89:14)

    // Test Suites: 3 failed, 3 total
    // Tests:       0 total
    // Snapshots:   0 total
    // Time:        3.217 s
    // Ran all test suites.                              npm run test
    // >> F:\Muse Operations Drive\Projects\Flowdometer>

    // > Flowdometer@1.0.0 test
    // > npm run test:unit


    // > Flowdometer@1.0.0 test:unit
    // > sfdx-lwc-jest -- --config jest.config.js

    //  FAIL  force-app/main/default/lwc/__tests__/modal.mock.js
    //   ● Test suite failed to run

    //     TypeError: Class extends value undefined is not a constructor or null

    //       2 | import { LightningElement } from 'lwc';
    //       3 |
    //     > 4 | export default class MockedModal extends LightningElement {
    //         |                                          ^
    //       5 |   name = 'mockedModal';
    //       6 |   slots = { content: [] };
    //       7 |   addEventListener = jest.fn((event, callback) => {

    //       at Object.LightningElement (force-app/main/default/lwc/__tests__/modal.mock.js:4:42)

    //  FAIL  force-app/main/default/lwc/__tests__/modal.test.js
    //   ● Test suite failed to run
                                                                                                                            
    //     TypeError: Class extends value undefined is not a constructor or null                                               
                                                                                                                            
    //       2 | import { LightningElement, api, track } from 'lwc';                                                           
    //       3 |                                                                                                               
    //     > 4 | export default class MockedModal extends LightningElement {                                                   
    //         |                                          ^                                                                    
    //       5 |   // Emulating public properties
    //       6 |   @api publicPropertyExample;
    //       7 |

    //       at Object.LightningElement (force-app/main/default/lwc/__mocks__/modal.js:4:42)
    //       at Object.require (force-app/main/default/lwc/__tests__/modal.test.js:3:1)

    //  FAIL  force-app/main/default/lwc/__tests__/flowdometerInstructions.test.js
    //   ● Test suite failed to run

    //     TypeError: Cannot read properties of undefined (reading 'default')

    //        5 |   return {
    //        6 |     __esModule: true,
    //     >  7 |     default: MockedModal,
    //          |              ^
    //        8 |   };
    //        9 | }, { virtual: true });
    //       10 | export default class FlowdometerInstructions extends LightningElement {

    //       at MockedModal (force-app/main/default/lwc/flowdometerInstructions/flowdometerInstructions.js:7:14)
    //       at Object.require (force-app/main/default/lwc/flowdometerInstructions/flowdometerInstructions.html.compiled:7:1)  
    //       at Object.require (force-app/main/default/lwc/flowdometerInstructions/flowdometerInstructions.js:1:26)
    //       at Object.require (force-app/main/default/lwc/__tests__/flowdometerInstructions.test.js:3:1)

    // Test Suites: 3 failed, 3 total
    // Tests:       0 total
    // Snapshots:   0 total
    // Time:        2.644 s
    // Ran all test suites.