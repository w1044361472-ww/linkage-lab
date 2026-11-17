import codecTest from './Codec.test';
import ruleEngineTest from './RuleEngine.test';

export default function testsuite() {
  ruleEngineTest();
  codecTest();
}
