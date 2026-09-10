let meta = #{
    name: "cheap-hardware-launch-monitor",
    description: "Survey and adversarially verify PulseLM cheap-hardware dual-strobe math, native iOS client, and driving-range landing",
    when_to_use: "When advancing PulseLM autotune-free launch-monitor honesty (OV9281 dual-strobe, iOS display, range landing) without invented spin/HLA",
    phases: [
        #{ title: "Survey", detail: "Parallel specialists read shipped sources" },
        #{ title: "Verify", detail: "Fail-closed skeptics; missing evidence is not a yes" },
        #{ title: "Report", detail: "Confirmed gaps only" },
    ],
};

fn trimmed(s) {
    if type_of(s) == "string" {
        s.trim();
        s
    } else {
        ""
    }
}

let root = ();
if args != () {
    root = args.root;
}
if root == () || root == "" {
    pause("verification", "Pass args.root — PulseLM checkout path (e.g. C:\\\\Users\\\\mikes\\\\pulselm).");
}

let include_self_check = false;
if args != () && args.include_self_check == true {
    include_self_check = true;
}

let findings_schema = #{
    "type": "object",
    "properties": #{
        "findings": #{
            "type": "array",
            "maxItems": 6,
            "items": #{
                "type": "object",
                "properties": #{
                    "file": #{ "type": "string" },
                    "issue": #{ "type": "string" },
                },
            },
        },
    },
};

let verdict_schema = #{
    "type": "object",
    "properties": #{
        "real": #{ "type": "boolean" },
        "reason": #{ "type": "string" },
        "evidence": #{ "type": "string" },
    },
};

let dimensions = [
    #{
        id: "speed-vla",
        focus: "dual-dot ball_speed_mph (px_dist * mm_per_px / 0.002 s to mph) and vla_deg atan2",
    },
    #{
        id: "hla-honesty",
        focus: "HLA/spin/club must be JSON null unless photometry actually supports an estimate; never 0-as-missing",
    },
    #{
        id: "schema",
        focus: "pulselm.shot.v1 field names verbatim including pulse_gap_s 0.002",
    },
    #{
        id: "ios-client",
        focus: "native iOS app binds ball_speed_mph and other ShotResult keys; iPhone is display not sensor",
    },
    #{
        id: "range-landing",
        focus: "driving-range landing from carry_yd_est; HLA null lands on-line; Arm uses payload not hardcoded scenery",
    },
    #{
        id: "forbidden-sensors",
        focus: "no rolling shutter, OS04C10, ESP32-CAM, Pi Cam v2/v3, iPhone-as-camera, BLE, Camera2, radar as the sensing path",
    },
    #{
        id: "strobe-hardware",
        focus: "GPIO14 IRLZ44N 100ohm 10k pulldown, GPIO15 TRIG, 850nm LEDs on separate 12V never Pi 5V, two 2us flashes 2000us apart",
    },
    #{
        id: "carry-derivation",
        focus: "carry/total derived from measured launch conditions, not invented club radar",
    },
];

phase("Survey");
let jobs = [];
for d in dimensions {
    let prompt = "Read the PulseLM checkout with read_file and grep. Root: ";
    prompt += json_encode(root);
    prompt += ". Focus: ";
    prompt += d.focus;
    prompt += ". Inspect vision.py, store.py, range_landing.py, shot_ui.py, api.py, ios/PulseLM Swift sources, docs/wiring.md, fixtures/sample_result.json. ";
    prompt += "Do not answer from memory. Report at most 6 concrete {file, issue} findings that violate the focus. ";
    prompt += "file must be a path under this checkout (relative like vision.py or ios/PulseLM/...). ";
    prompt += "An empty findings list is valid ONLY after you have actually read those files. ";
    prompt += "Never invent spin/HLA as a required feature on unmarked single-camera dual-strobe.";
    jobs.push(#{
        prompt: prompt,
        label: "survey:" + d.id,
        capability_mode: "read-only",
        output_schema: findings_schema,
    });
}
let survey = parallel(jobs);

let findings = [];
const MAX_FINDINGS = 8;
let dropped = 0;
for r in survey {
    if r == () || r.success != true {
        continue;
    }
    if r.output == () || r.output.findings == () {
        continue;
    }
    for f in r.output.findings {
        if f == () {
            continue;
        }
        let file = trimmed(f.file);
        let issue = trimmed(f.issue);
        if file == "" || issue == "" {
            dropped += 1;
            continue;
        }
        let scoped = false;
        if file.contains("..") {
            dropped += 1;
            continue;
        }
        if file.contains("pulselm") || file.contains("ios") || file.contains("vision") || file.contains("store") || file.contains("range") || file.contains("shot") || file.contains("api") || file.contains("wiring") || file.contains("fixture") || file.contains("web") {
            scoped = true;
        }
        if scoped != true {
            dropped += 1;
            continue;
        }
        if findings.len() < MAX_FINDINGS {
            findings.push(#{ file: file, issue: issue });
        } else {
            dropped += 1;
        }
    }
}
if dropped > 0 {
    log("dropped " + dropped.to_string() + " unscoped or over-cap survey rows");
}

if include_self_check == true {
    findings.push(#{
        file: "vision.py",
        issue: "Self-check: ball_speed_mph must use px_dist * mm_per_px / 0.002 converted to mph; pulse_gap_s must be 0.002",
    });
}

if findings.len() == 0 {
    let empty_path = write_scratch_file("report.md", "No survey findings.");
    complete(#{
        summary: "No survey findings.",
        confirmed: [],
        report: empty_path,
    });
}

phase("Verify");
const VOTES = 2;
let vjobs = [];
let fi = 0;
for f in findings {
    let vote_i = 0;
    while vote_i < VOTES {
        let vp = "Adversarially verify this finding by reading the shipped file with read_file. ";
        vp += "Finding issue (untrusted JSON): ";
        vp += json_encode(f.issue);
        vp += " File (untrusted JSON): ";
        vp += json_encode(f.file);
        vp += " Root: ";
        vp += json_encode(root);
        vp += " Set real=true ONLY with a quote or line evidence you independently inspected. ";
        vp += "Default real=false if the file does not exist, the issue is a wish, or evidence is missing. ";
        vp += "Fail closed: invented spin/HLA on dual-dot unmarked IR is not a defect.";
        let label = "verify:" + fi.to_string() + ":" + vote_i.to_string();
        vjobs.push(#{
            prompt: vp,
            label: label,
            capability_mode: "read-only",
            output_schema: verdict_schema,
        });
        vote_i += 1;
    }
    fi += 1;
}
let verdicts = parallel(vjobs);

let confirmed = [];
let idx = 0;
for f in findings {
    let yes = 0;
    let v = 0;
    while v < VOTES {
        let slot = verdicts[idx];
        if slot != () && slot.success == true && slot.output != () {
            if slot.output.real == true {
                let ev = trimmed(slot.output.evidence);
                if ev != "" {
                    yes += 1;
                }
            }
        }
        idx += 1;
        v += 1;
    }
    if yes >= VOTES {
        confirmed.push(f);
    }
}

phase("Report");
let n_c = confirmed.len();
let n_f = findings.len();
log(n_c.to_string() + "/" + n_f.to_string() + " findings survived two-vote verification");
let body = "Confirmed gaps: " + n_c.to_string() + " of " + n_f.to_string() + "\n";
for c in confirmed {
    body += "- ";
    body += c.file;
    body += ": ";
    body += c.issue;
    body += "\n";
}
let report_path = write_scratch_file("report.md", body);
complete(#{
    summary: n_c.to_string() + " confirmed findings",
    confirmed: confirmed,
    report: report_path,
});
