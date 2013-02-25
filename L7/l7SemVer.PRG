* L7SemVer.prg - Semantic Versioning classes and functions for VFP
*   reference: http://semver.org/ 
*
#define L7_SEMVER_PATTERN_STEM '(\d+)\.(\d+)\.(\d+)'
#define L7_SEMVER_PATTERN_SUFFIX_LOOSE  '([a-zA-Z][a-zA-Z0-9-]*)?'
#define L7_SEMVER_PATTERN_SUFFIX_STRICT '(?:-([0-9A-Za-z-]*)(?:~(\d+))?)?'

* #define L7_SEMVER_PATTERN_SUFFIX_STRICT '(?:([a-zA-Z][a-zA-Z-]*)([0-9]{3}))?'

* <major>.<minor>.<patch><suffix>
__main()
return 
* --------------------------------------------------------- *
function __main
  __test()  
endfunc 
* --------------------------------------------------------- *
function __test
  local loSV1 as L7SemVer of L7SemVer.prg, loSV2 as L7SemVer of L7SemVer.prg, lcStr 
  * clear
  ? 
  ? datetime()
  loSV1 = createobject("L7SemVer", '1.2.3-beta')
  *
  loSV2 = createobject("L7SemVer", '2.1.1')
  
  ?
  ? loSV1.compareWith(loSV2)

  loSV2 = createobject("L7SemVer", '1.2.3')
  ?
  ? loSV1.compareWith(loSV2)

  loSV2 = createobject("L7SemVer", '1.2.3-gamma')
  ?
  ? loSV1.compareWith(loSV2)

  loSV2 = createobject("L7SemVer", '1.2.3-beta~2')
  ?
  ? loSV1.compareWith(loSV2)
  
  lcStr = '1.952'
  ? m.lcStr, iif(L7isValidSemVer(m.lcStr), 'is', 'is NOT') + " a valid SemVer"
  lcStr = '1.952.0'
  ? m.lcStr, iif(L7isValidSemVer(m.lcStr), 'is', 'is NOT') + " a valid SemVer"

endfunc && __test
  
* ----------------------------------------------------- 
function L7isValidSemVer(tcSV)
  local loSV
  loSV = createobject("L7SemVer")
  return loSV.isValid(m.tcSV)
endfunc 

************************************************************************
define class L7SemVer as line
************************************************************************
  ver = null
  major = null
  minor = null
  patch = null
  *!*    suffix = null
  *!*    suffix_alpha = null
  *!*    suffix_number = null
  *!*    is_suffix_strict = .f. 
  prerelease_name = null  && null unless - follows patch #
  prerelease_seq = null   && null unless ~ follows prerelease_name
  
  * --------------------------------------------------------- *
  function init(tcSV)
    if vartype(m.tcSV) = "C"
      this.toProperties(m.tcSV)
    endif
    return 
  endfunc 
  * --------------------------------------------------------- *
  function getMatches(tcSV)
    local loRE as VBScript.RegExp && L7_REGEXP_CLASS
    local loMatches as VBScript_RegExp_55.MatchCollection 
    loRE = createobject('VBScript.RegExp')
    loRE.Pattern = '^' + L7_SEMVER_PATTERN_STEM + L7_SEMVER_PATTERN_SUFFIX_STRICT + '$' 
    loMatches = loRE.Execute(m.tcSV)
    return m.loMatches
  endfunc 
  * --------------------------------------------------------- *
  function isValid(tcSV)
    local loMatches as VBScript_RegExp_55.MatchCollection 
    loMatches = this.getMatches(m.tcSV)
    return loMatches.Count >= 1
  endfunc 
  * --------------------------------------------------------- *
  function toProperties(tcSV, toObj)
    local loMatches as VBScript_RegExp_55.MatchCollection 
    if !vartype(m.toObj) = 'O'
      toObj = this
    endif
    loMatches = this.getMatches(m.tcSV)
    if loMatches.Count < 1
      error "Not a valid semver: " + transform(m.tcSV)
    endif 
    loMatch = loMatches.Item(0) 
    with m.toObj
      .ver = m.tcSV && keep original string on hand
      .major = val(loMatch.submatches[0])
      .minor = val(loMatch.submatches[1])
      .patch = val(loMatch.submatches[2])
      .prerelease_name = loMatch.submatches[3]
      .prerelease_seq = iif(isnull(loMatch.submatches[4]), 0, val(loMatch.submatches[4]))
    endwith 
    return 
  endfunc 
  * --------------------------------------------------------- *
  function toString()
    local lcStr
    with this
      lcStr = transform(.major) + "." + transform(.minor) + "." + transform(.patch)
      lcStr = m.lcStr + .suffixToString()
    endwith 
    return m.lcStr
  endfunc && toString
  * --------------------------------------------------------- *
  function suffixToString()
    local lcStr
    lcStr = ""
    if !isnull(this.prerelease_name)
      lcStr = m.lcStr + "-" + this.prerelease_name
      if !isnull(this.prerelease_seq)
        lcStr = m.lcStr + '~' + transform(this.prerelease_seq) && [[ check decimals: allowed? 
      endif
    endif 
    return m.lcStr
  endfunc && suffixToString
  * --------------------------------------------------------- *
  function isPreRelease()
    return !isnull(this.prerelease_name)
  endfunc 
  * --------------------------------------------------------- *
  function isCompatibleWith(tvSV)
    local loOther
    loOther = iif(vartype(m.tvSV) = 'O', m.tvSV, createobject(this.Class, m.tvSV))
    return this.major = loOther.major 
  endfunc 
  * --------------------------------------------------------- *
  function isNewerThan(tvSV)
    local loOther
    loOther = iif(vartype(m.tvSV) = 'O', m.tvSV, createobject(this.Class, m.tvSV))
    return this.major > loOther.major or ;
      this.major = loOther.major and ;
      ( this.minor > loOther.minor or ;
        this.minor = loOther.minor and ;
        ( this.patch > loOther.patch or ;
          this.patch = loOther.patch and ;
          !isnull(loOther.prerelease_name) and ;
          ( isnull(this.prerelease_name) or ;
            this.prerelease_name > loOther.prerelease_name or ;
            this.prerelease_name = loOther.prerelease_name and ;
            this.prerelease_seq > loOther.prerelease_seq ;
          ) ;
        ) ;
      ) 
       
  endfunc 
  * --------------------------------------------------------- *
  function isSameAs(tvSV)
    local loOther
    loOther = iif(vartype(m.tvSV) = 'O', m.tvSV, createobject(this.Class, m.tvSV))
    return this.ver == loOther.ver    
  endfunc 
  * --------------------------------------------------------- *
  function isOlderThan(tvSV)
    return !this.isNewerThanOrSameAs(m.tvSV)
  endfunc 
  * --------------------------------------------------------- *
  function isNewerThanOrSameAs(tvSV)
    return this.isNewerThan(m.tvSV) or this.isSameAs(m.tvSV)
  endfunc 
  * --------------------------------------------------------- *
  function compareWith(tvSV)
    local loOther, lcOut
    loOther = iif(vartype(m.tvSV) = 'O', m.tvSV, createobject(this.Class, m.tvSV))
    text to lcOut textmerge noshow pretext 3
    
      I am <<this.ver>>, a <<iif(this.isPreRelease(), 'PRE-RELEASE', 'PRODUCTION')>> version
      My friend is <<m.loOther.ver>>, a <<iif(loOther.isPreRelease(), 'PRE-RELEASE', 'PRODUCTION')>> version
      I am <<iif(this.isCompatibleWith(m.loOther),'', 'NOT ')>>COMPATIBLE with <<loOther.ver>>
      I am <<iif(this.isNewerThan(m.loOther),'', 'NOT ')>>NEWER than <<loOther.ver>>
      I am <<iif(this.isSameAs(m.loOther),'', 'NOT ')>>THE SAME as <<loOther.ver>>
      I am therefore <<iif(this.isOlderThan(m.loOther),'', 'NOT ')>>OLDER than <<loOther.ver>>
      My friend <<loOther.ver>> is <<iif(loOther.isNewerThan(THIS),'', 'NOT ')>>NEWER than me
    endtext
    return m.lcOut
  endfunc 
  * --------------------------------------------------------- *
enddefine && L7SemVer
************************************************************************

#if .f.

* pattern: 

New: ^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z-]*)(?:~(\d+))?)?$ 
Old: ^(\d+)\.(\d+)\.(\d+)(?:([a-zA-Z][a-zA-Z-]*)([0-9]{3}))?$

(global, multi-line)

*  test input string:
123.21.0-abc~12
123.22.0
a123.23.0
123.24.0-abc~002
123.25.0-abc02~
123.26.3

* test result:
Match 1 (0, 15): 123.21.0-abc~12
  Submatch 1: ¦123¦
  Submatch 2: ¦21¦
  Submatch 3: ¦0¦
  Submatch 4: ¦abc¦
  Submatch 5: ¦12¦
Match 2 (17, 8): 123.22.0
  Submatch 1: ¦123¦
  Submatch 2: ¦22¦
  Submatch 3: ¦0¦
  Submatch 4: ¦.NULL.¦
  Submatch 5: ¦.NULL.¦
Match 3 (38, 16): 123.24.0-abc~002
  Submatch 1: ¦123¦
  Submatch 2: ¦24¦
  Submatch 3: ¦0¦
  Submatch 4: ¦abc¦
  Submatch 5: ¦002¦
Match 4 (73, 8): 123.26.3
  Submatch 1: ¦123¦
  Submatch 2: ¦26¦
  Submatch 3: ¦3¦
  Submatch 4: ¦.NULL.¦
  Submatch 5: ¦.NULL.¦


* OLD test input string: 
123.23.0abc12
123.23.0
a123.23.0
145.18.a
123.23.0abc002
123.23.0abc02
123.22.3

* OLD test result:
Match 1 (15, 8): 123.23.0
  Submatch 1: ¦123¦
  Submatch 2: ¦23¦
  Submatch 3: ¦0¦
  Submatch 4: ¦--¦
  Submatch 5: ¦--¦
Match 2 (46, 14): 123.23.0abc002
  Submatch 1: ¦123¦
  Submatch 2: ¦23¦
  Submatch 3: ¦0¦
  Submatch 4: ¦abc¦
  Submatch 5: ¦002¦
Match 3 (77, 8): 123.22.3
  Submatch 1: ¦123¦
  Submatch 2: ¦22¦
  Submatch 3: ¦3¦
  Submatch 4: ¦--¦
  Submatch 5: ¦--¦

11/17/2011 - Update on pre-release version suffixes:

A pre-release version number MAY be denoted by appending a dash and a
qualifying string immediately following the patch version. The qualifying
string is comprised of a mandatory identifier and an optional sequence number.
If the sequence number is used, it MUST be separated from the identifier by a
tilde. Identifiers MUST be comprised of only alphanumerics plus dash
[0-9A-Za-z-]. Sequence numbers MUST be comprised of only digits [0-9].
Pre-release versions satisfy but have a lower precedence than the associated
normal version. Precedence SHOULD be determined by lexicographic ASCII sort
order of the identifier followed by numeric sort order of the sequence number.
If the sequence number is absent, it MUST be considered to be zero. For
example: 1.0.0-alpha < 1.0.0-alpha~1 < 1.0.0-beta~2 < 1.0.0-beta~11 <
1.0.0-rc~1 < 1.0.0.

#endif
