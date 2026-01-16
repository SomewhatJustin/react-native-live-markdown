import {MarkdownTextInput} from '../src';
import type {parseMarkdown} from '../src';

global.jsi_setMarkdownRuntime = jest.fn();
global.jsi_registerMarkdownWorklet = jest.fn();
global.jsi_unregisterMarkdownWorklet = jest.fn();

const parseMarkdownMock: typeof parseMarkdown = () => {
  'worklet';

  return [];
};

const getWorkletRuntimeMock = () => ({});

export {MarkdownTextInput, parseMarkdownMock as parseMarkdown, getWorkletRuntimeMock as getWorkletRuntime};
