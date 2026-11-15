import json
import pathlib
import re
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]

class SourceContract(unittest.TestCase):
    def test_demo_fixture_and_six_kinds(self):
        data=json.loads((ROOT/'assets/data/demo.json').read_text())
        assert len(data['exams'])>=3
        types={q['kind'] for exam in data['exams'] for q in exam['questions']}
        self.assertEqual(types, {'single','multiple','true_false','short','matching','essay'})
        self.assertTrue(any('\\int_' in q['prompt'] for x in data['exams'] for q in x['questions']))
        for exam in data['exams']:
            self.assertEqual(len(exam['questions']),exam['question_count'])
            self.assertEqual(sorted(q['position'] for q in exam['questions']),list(range(1,len(exam['questions'])+1)))

    def test_no_removed_business_modules(self):
        combined='\n'.join(p.read_text() for p in (ROOT/'lib').rglob('*.dart'))
        for blocked in ['affiliate','commission','referral_code','ai_analysis','openai_api_key','payment_webhook']:
            self.assertNotIn(blocked,combined.lower())

    def test_schema_rls_and_answer_isolation(self):
        sql=(ROOT/'backend/01_schema.sql').read_text().lower()
        self.assertIn('create table if not exists public.eh_answer_keys',sql)
        self.assertIn('eh_keys_admin',sql)
        self.assertIn('alter table public.%i enable row level security',sql)
        self.assertNotIn('revoke all on all tables in schema public',sql)
        funcs=(ROOT/'backend/02_functions.sql').read_text().lower()
        self.assertIn('public.eh_submit_attempt',funcs)
        self.assertIn('private.eh_admin()',funcs)
        self.assertIn('score-penalties',funcs)
        self.assertIn('sess.last_draft',funcs)

    def test_native_lifecycle_and_workflow(self):
        kotlin=(ROOT/'native/MainActivity.kt').read_text()
        self.assertIn('Intent.ACTION_SCREEN_OFF',kotlin)
        self.assertIn('FLAG_SECURE',kotlin)
        self.assertIn('onStop()',kotlin)
        workflow=(ROOT/'.github/workflows/build-apk.yml').read_text()
        self.assertIn('flutter analyze',workflow)
        self.assertIn('flutter test',workflow)
        self.assertIn('flutter build apk',workflow)

    def test_latex_formatting(self):
        content=(ROOT/'lib/widgets/rich_math.dart').read_text()
        self.assertIn('Math.tex(',content)
        self.assertIn('onErrorFallback:',content)
        self.assertIn('SingleChildScrollView(scrollDirection:Axis.horizontal',content)

    def test_bulk_import_staging(self):
        validator=(ROOT/'lib/data/import_validation.dart').read_text()
        studio=(ROOT/'lib/features/studio.dart').read_text()
        self.assertIn('static ExamImport parse',validator)
        self.assertIn('Tạo bản nháp từ JSON',studio)
        self.assertIn('createExam(parsed.metadata)',studio)
        self.assertIn('addQuestion(id,',studio)
        self.assertNotIn('publishExam(id)',studio[studio.index('class ExamImportPage'):studio.index('class ExamCreatePage')])

    def test_user_settings_persisted(self):
        state=(ROOT/'lib/core/app_state.dart').read_text()
        self.assertIn('eh_text_scale',state)
        self.assertIn('eh_contrast',state)
        self.assertIn('eh_less_motion',state)
        ui=(ROOT/'lib/features/account.dart').read_text()
        self.assertIn('state.updatePreferences(scale:',ui)

    def test_dart_bracket_sanity(self):
        # A lightweight lexical test (NOT a replacement for flutter analyze).
        # Removes comments, strings, and Dart raw/normal interpolation enough to
        # catch accidental unbalanced braces introduced while authoring.
        for p in (ROOT/'lib').rglob('*.dart'):
            source=p.read_text()
            stack=[]
            # Multiline string safe approximated by lexical ignoring quoted content.
            i=0;quote=None;triple=False;raw=False
            while i<len(source):
                ch=source[i]
                if quote:
                    if not raw and ch=='\\':i+=2;continue
                    if triple and source[i:i+3]==quote*3:quote=None;triple=False;raw=False;i+=3;continue
                    if not triple and ch==quote:quote=None;raw=False;i+=1;continue
                    i+=1;continue
                if source[i:i+2]=='//':
                    i=source.find('\n',i)
                    if i<0:break
                    continue
                if source[i:i+2]=='/*':
                    j=source.find('*/',i+2)
                    i=len(source) if j<0 else j+2;continue
                if (ch=='r' and i+1<len(source) and source[i+1] in ('"',"'")):
                    raw=True;i+=1;continue
                if ch in ('"',"'"):
                    quote=ch;triple=source[i:i+3]==ch*3
                    i+=3 if triple else 1;continue
                if ch in '({[':stack.append((ch,i))
                if ch in ')}]':
                    self.assertTrue(stack,f'{p}: unexpected {ch} at {i}')
                    opening,_=stack.pop()
                    self.assertEqual({'(':')','{':'}','[':']'}[opening],ch,f'{p}: wrong closing {ch}')
                i+=1
            self.assertFalse(stack,f'{p}: unmatched {stack[-1] if stack else None}')

if __name__=='__main__':unittest.main()
