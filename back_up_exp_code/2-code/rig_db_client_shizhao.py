from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, date
from zoneinfo import ZoneInfo
from typing import Any, Optional, Callable
from pathlib import Path

import requests
import csv
import ast
import shutil


# =============================================================================
# Exceptions
# =============================================================================

class DBClientError(RuntimeError):
    pass


class SessionAborted(RuntimeError):
    """Raised when the user explicitly aborts from a warning dialog."""
    pass


# =============================================================================
# Data models
# =============================================================================

@dataclass
class MouseRow:
    mouse_id: int
    mouse_name: str


@dataclass
class ExperimenterRow:
    experimenter_id: int
    experimenter_name: str
    experimenter_email: Optional[str] = None


@dataclass
class SessionTypeRow:
    session_type_id: int
    session_type_name: str


@dataclass
class SessionRow:
    session_id: int
    mouse_id: int
    experiment_name: str
    experiment_id: int
    rig_id: Optional[int]
    experimenter_id: Optional[int]
    experimenter_name: Optional[str]
    session_type_id: Optional[int]
    session_type_name: Optional[str]
    session_at: str
    is_analyzed: bool
    parameters: Optional[dict[str, Any]]
    performance: Optional[dict[str, Any]]
    next_session_parameters: Optional[dict[str, Any]]
    links: Optional[str]


@dataclass
class RigRewardPolicy:
    """
    Normalized rig reward policy for runtime use.
    This comes from the server's rig calibration logic.

    NOTE: computed_valve_ms is a FLOAT (Arduino accepts float).
    """
    rig_id: int
    target_reward_ul: Optional[float]
    computed_valve_ms: Optional[float]
    reward_warning: Optional[str]
    calibration_id: Optional[int]
    performed_at: Optional[str]
    cal_min_ul: Optional[float]
    cal_max_ul: Optional[float]
    closest_ul: Optional[float]
    min_ms: Optional[float]
    max_ms: Optional[float]


@dataclass
class MouseSelection:
    mouse_name: str
    mouse_id: Optional[int]
    from_db: bool


@dataclass
class SessionContext:
    mouse_name: str
    mouse_id: Optional[int]
    experiment_name : str
    experiment_id: int
    rig_id: Optional[int]
    experimenter_id: Optional[int]
    session_type_id: Optional[int]

    session_id: Optional[int]
    session_num: int
    session_at: datetime

    local_dir: Path
    nas_dir: Path
    foldername: str
    smb_link: Optional[str]

    parameters: dict[str, Any]


# =============================================================================
# Small helpers
# =============================================================================

def format_mouse_option(mouse: MouseRow) -> str:
    return f"{mouse.mouse_name}  (ID {mouse.mouse_id})"


def build_mouse_dropdown(mice: list[MouseRow]) -> tuple[list[str], dict[str, int]]:
    options = [format_mouse_option(m) for m in mice]
    option_to_id = {format_mouse_option(m): int(m.mouse_id) for m in mice}
    return options, option_to_id


def parse_mouse_name_from_option(option: str) -> str:
    if " (ID " in option:
        return option.split(" (ID ", 1)[0].strip()
    return option.strip()


def to_windows_path(p: str | Path) -> str:
    return str(p).replace("/", "\\")


def build_smb_link(smb_base_unc: str, mouse_name: str, foldername: str) -> str:
    base = str(smb_base_unc).rstrip("/").rstrip("\\")
    return to_windows_path(f"{base}\\{mouse_name}\\{foldername}")


# =============================================================================
# Low-level HTTP client
# =============================================================================

class RigDBClient:
    def __init__(
        self,
        base_url: str,
        *,
        timeout_s: float = 10.0,
        session: Optional[requests.Session] = None,
    ):
        self.base_url = base_url.rstrip("/")
        self.timeout_s = float(timeout_s)
        self.http = session or requests.Session()

    def _url(self, path: str) -> str:
        if not path.startswith("/"):
            path = "/" + path
        return self.base_url + path

    def _raise_for_status(self, r: requests.Response, context: str) -> None:
        if 200 <= r.status_code < 300:
            return
        try:
            detail = r.json()
        except Exception:
            detail = r.text.strip()
        raise DBClientError(f"{context} failed: HTTP {r.status_code} :: {detail}")

    def _get_json(self, path: str, *, params: dict[str, Any] | None = None, context: str = "GET") -> Any:
        url = self._url(path)
        try:
            r = self.http.get(url, params=params, timeout=self.timeout_s)
        except Exception as e:
            raise DBClientError(f"{context} {url} failed (network): {e}")
        self._raise_for_status(r, f"{context} {url}")
        try:
            return r.json()
        except Exception as e:
            raise DBClientError(f"{context} {url} returned non-JSON: {e}")

    def _post_json(self, path: str, payload: dict[str, Any], *, context: str = "POST") -> Any:
        url = self._url(path)
        try:
            r = self.http.post(url, json=payload, timeout=self.timeout_s)
        except Exception as e:
            raise DBClientError(f"{context} {url} failed (network): {e}")
        self._raise_for_status(r, f"{context} {url}")
        try:
            return r.json()
        except Exception as e:
            raise DBClientError(f"{context} {url} returned non-JSON: {e}")

    def _patch_json(self, path: str, payload: dict[str, Any], *, context: str = "PATCH") -> Any:
        url = self._url(path)
        try:
            r = self.http.patch(url, json=payload, timeout=self.timeout_s)
        except Exception as e:
            raise DBClientError(f"{context} {url} failed (network): {e}")
        self._raise_for_status(r, f"{context} {url}")
        try:
            return r.json()
        except Exception as e:
            raise DBClientError(f"{context} {url} returned non-JSON: {e}")

    # ---- endpoints ----

    def get_mice_for_experiment(self, experiment_id: int) -> list[MouseRow]:
        data = self._get_json(f"/api/experiments/{int(experiment_id)}/mice", context="GET mice")
        out: list[MouseRow] = []
        for m in data.get("mice", []):
            out.append(MouseRow(mouse_id=int(m["mouse_id"]), mouse_name=str(m["mouse_name"])))
        return out

    def get_experimenters(self) -> list[ExperimenterRow]:
        data = self._get_json("/api/experimenters", context="GET experimenters")
        out: list[ExperimenterRow] = []
        for x in data.get("experimenters", []):
            out.append(
                ExperimenterRow(
                    experimenter_id=int(x["experimenter_id"]),
                    experimenter_name=str(x["experimenter_name"]),
                    experimenter_email=(str(x["experimenter_email"]) if x.get("experimenter_email") is not None else None),
                )
            )
        return out

    def create_experimenter(self, experimenter_name: str, experimenter_email: Optional[str] = None) -> ExperimenterRow:
        payload: dict[str, Any] = {"experimenter_name": experimenter_name}
        if experimenter_email is not None:
            payload["experimenter_email"] = experimenter_email

        data = self._post_json("/api/experimenters", payload, context="POST experimenter")
        return ExperimenterRow(
            experimenter_id=int(data["experimenter_id"]),
            experimenter_name=str(data["experimenter_name"]),
            experimenter_email=(str(data["experimenter_email"]) if data.get("experimenter_email") is not None else None),
        )

    def get_session_types(self) -> list[SessionTypeRow]:
        data = self._get_json("/api/session-types", context="GET session types")
        out: list[SessionTypeRow] = []
        for x in data.get("session_types", []):
            out.append(
                SessionTypeRow(
                    session_type_id=int(x["session_type_id"]),
                    session_type_name=str(x["session_type_name"]),
                )
            )
        return out

    def create_session_type(self, session_type_name: str) -> SessionTypeRow:
        data = self._post_json(
            "/api/session-types",
            {"session_type_name": session_type_name},
            context="POST session type",
        )
        return SessionTypeRow(
            session_type_id=int(data["session_type_id"]),
            session_type_name=str(data["session_type_name"]),
        )

    def get_last_session(
        self,
        *,
        mouse_id: int,
        experiment_name: str,
        experiment_id: int,
        require_analyzed: bool = True,
    ) -> Optional[SessionRow]:
        data = self._get_json(
            "/api/sessions/last",
            params={
                "mouse_id": int(mouse_id),
                "experiment_name": str(experiment_name),
                "experiment_id": int(experiment_id),
                "require_analyzed": str(bool(require_analyzed)).lower(),
            },
            context="GET last session",
        )
        if not data.get("found"):
            return None

        s = data.get("session") or {}

        # # Debugging: show exactly what keys the server returned
        # print("[db debug] last session keys:", sorted(s.keys()))
        # print("[db debug] last session:", s)

        params = s.get("parameters") or {}
        metadata = params.get("metadata") or {}

        returned_experiment_name = (
            s.get("experiment_name")
            or metadata.get("experiment_name")
            or experiment_name
        )

        return SessionRow(
            session_id=int(s["session_id"]),
            mouse_id=int(s["mouse_id"]),
            experiment_id=int(s["experiment_id"]),
            experiment_name=str(returned_experiment_name),
            rig_id=(int(s["rig_id"]) if s.get("rig_id") is not None else None),
            experimenter_id=(int(s["experimenter_id"]) if s.get("experimenter_id") is not None else None),
            experimenter_name=(str(s["experimenter_name"]) if s.get("experimenter_name") is not None else None),
            session_type_id=(int(s["session_type_id"]) if s.get("session_type_id") is not None else None),
            session_type_name=(str(s["session_type_name"]) if s.get("session_type_name") is not None else None),
            session_at=str(s["session_at"]),
            is_analyzed=bool(s.get("is_analyzed")),
            parameters=s.get("parameters"),
            performance=s.get("performance"),
            next_session_parameters=s.get("next_session_parameters"),
            links=s.get("links"),
        )

        # return SessionRow(
        #     session_id=int(s["session_id"]),
        #     mouse_id=int(s["mouse_id"]),
        #     experiment_name=str(returned_experiment_name),
        #     rig_id=(int(s["rig_id"]) if s.get("rig_id") is not None else None),
        #     experimenter_id=(int(s["experimenter_id"]) if s.get("experimenter_id") is not None else None),
        #     experimenter_name=(str(s["experimenter_name"]) if s.get("experimenter_name") is not None else None),
        #     session_type_id=(int(s["session_type_id"]) if s.get("session_type_id") is not None else None),
        #     session_type_name=(str(s["session_type_name"]) if s.get("session_type_name") is not None else None),
        #     session_at=str(s["session_at"]),
        #     is_analyzed=bool(s.get("is_analyzed")),
        #     parameters=s.get("parameters"),
        #     performance=s.get("performance"),
        #     next_session_parameters=s.get("next_session_parameters"),
        #     links=s.get("links"),
        # )

    def create_session(
        self,
        *,
        mouse_id: int,
        experiment_name: str,
        experiment_id: int,
        session_at: datetime,
        rig_id: Optional[int] = None,
        experimenter_id: Optional[int] = None,
        session_type_id: Optional[int] = None,
        parameters: Optional[dict[str, Any]] = None,
        links: Optional[str] = None,
    ) -> int:
        payload = {
            "mouse_id": int(mouse_id),
            "experiment_name": str(experiment_name),
            "experiment_id": int(experiment_id),
            "session_at": session_at.isoformat(),
            "rig_id": (int(rig_id) if rig_id is not None else None),
            "experimenter_id": (int(experimenter_id) if experimenter_id is not None else None),
            "session_type_id": (int(session_type_id) if session_type_id is not None else None),
            "parameters": parameters,
            "links": links,
        }
        data = self._post_json("/api/sessions", payload, context="POST session")
        return int(data["session_id"])

    def patch_session(
        self,
        session_id: int,
        *,
        rig_id: Optional[int] = None,
        experimenter_id: Optional[int] = None,
        session_type_id: Optional[int] = None,
        parameters: Optional[dict[str, Any]] = None,
        is_analyzed: Optional[bool] = None,
        performance: Optional[dict[str, Any]] = None,
        next_session_parameters: Optional[dict[str, Any]] = None,
        links: Optional[str] = None,
    ) -> None:
        payload: dict[str, Any] = {}
        if rig_id is not None:
            payload["rig_id"] = int(rig_id)
        if experimenter_id is not None:
            payload["experimenter_id"] = int(experimenter_id)
        if session_type_id is not None:
            payload["session_type_id"] = int(session_type_id)
        if parameters is not None:
            payload["parameters"] = parameters
        if is_analyzed is not None:
            payload["is_analyzed"] = bool(is_analyzed)
        if performance is not None:
            payload["performance"] = performance
        if next_session_parameters is not None:
            payload["next_session_parameters"] = next_session_parameters
        if links is not None:
            payload["links"] = links

        if not payload:
            return

        self._patch_json(f"/api/sessions/{int(session_id)}", payload, context="PATCH session")

    # =============================================================================
    # Reward policy
    # =============================================================================

    def get_rig_reward_policy(self, rig_id: int, *, target_reward_ul: Optional[float] = None) -> RigRewardPolicy:
        params: dict[str, Any] = {}
        if target_reward_ul is not None:
            params["target_reward_ul"] = float(target_reward_ul)

        data = self._get_json(
            f"/api/rigs/{int(rig_id)}/reward_policy",
            params=params,
            context="GET rig reward policy",
        )

        def f(x):
            return float(x) if x is not None else None

        def i(x):
            return int(x) if x is not None else None

        return RigRewardPolicy(
            rig_id=int(data["rig_id"]),
            target_reward_ul=f(data.get("target_reward_ul")),
            computed_valve_ms=f(data.get("computed_valve_ms")),
            reward_warning=(str(data["reward_warning"]) if data.get("reward_warning") is not None else None),
            calibration_id=i(data.get("calibration_id")),
            performed_at=(str(data["performed_at"]) if data.get("performed_at") is not None else None),
            cal_min_ul=f(data.get("cal_min_ul")),
            cal_max_ul=f(data.get("cal_max_ul")),
            closest_ul=f(data.get("closest_ul")),
            min_ms=f(data.get("min_ms")),
            max_ms=f(data.get("max_ms")),
        )


# =============================================================================
# Optional legacy backup: DataRecord.csv
# =============================================================================

@dataclass
class DataRecordHistory:
    session_already: int
    trial_already: int
    lag_list: list[float]
    nas_record_path: Path


class DataRecordCSV:
    HEADER = [
        "Session",
        "Date",
        "LagList for this experiment",
        "Performance",
        "Total Trial",
        "LagList for next experiment",
        "ifAnalyzed",
    ]

    def __init__(self, nas_base_dir: str | Path):
        self.nas_base_dir = Path(nas_base_dir)

    def get_history(
        self,
        mouse_name: str,
        default_lag_list: list[float],
        db_lag_override: Optional[list[float]] = None,
    ) -> DataRecordHistory:
        nas_mouse_path = self.nas_base_dir / mouse_name
        nas_mouse_path.mkdir(parents=True, exist_ok=True)
        nas_record_path = nas_mouse_path / "DataRecord.csv"

        session_already = 0
        trial_already = 0
        lag_list = list(db_lag_override) if db_lag_override is not None else list(default_lag_list)

        if nas_record_path.exists():
            try:
                with open(nas_record_path, "r", newline="", encoding="utf-8") as f:
                    reader = csv.reader(f)
                    next(reader, None)
                    last_row = None
                    for row in reader:
                        if row:
                            last_row = row
                    if last_row:
                        try:
                            session_already = int(last_row[0])
                        except Exception:
                            pass
                        try:
                            trial_already = int(last_row[4])
                        except Exception:
                            pass

                        if db_lag_override is None:
                            try:
                                parsed = ast.literal_eval(last_row[-2])
                                if isinstance(parsed, (list, tuple)) and parsed:
                                    lag_list = [float(x) for x in parsed]
                            except Exception:
                                pass
            except Exception as e:
                print(f"Warning: failed reading NAS {nas_record_path}: {e}")
        else:
            try:
                with open(nas_record_path, "w", newline="", encoding="utf-8") as f:
                    csv.writer(f).writerow(self.HEADER)
            except Exception as e:
                print(f"Warning: failed creating NAS {nas_record_path}: {e}")

        return DataRecordHistory(
            session_already=session_already,
            trial_already=trial_already,
            lag_list=[float(x) for x in lag_list],
            nas_record_path=nas_record_path,
        )

    def append_row(self, mouse_name: str, row: list[Any]) -> None:
        nas_record_path = self.nas_base_dir / mouse_name / "DataRecord.csv"
        try:
            with open(nas_record_path, "a", newline="", encoding="utf-8") as f:
                csv.writer(f).writerow(row)
        except Exception as e:
            print(f"Failed to append to NAS DataRecord.csv: {e}")


# =============================================================================
# Storage manager
# =============================================================================

class SessionStorageManager:
    def __init__(self, local_base_dir: str | Path, nas_base_dir: str | Path, smb_base_unc: str):
        self.local_base_dir = Path(local_base_dir)
        self.nas_base_dir = Path(nas_base_dir)
        self.smb_base_unc = str(smb_base_unc).rstrip("/").rstrip("\\")

    def make_folders(
        self,
        mouse_name: str,
        experiment_name:str,
        session_num: int,
        *,
        today: Optional[date] = None,
    ) -> tuple[Path, Path, str, str]:
        today = today or date.today()
        today_str = today.strftime("%m%d%Y")
        foldername = f"Session {session_num} - {today_str}"

        nas_dir = self.nas_base_dir /experiment_name/ mouse_name / foldername
        nas_dir.mkdir(parents=True, exist_ok=True)

        local_dir = self.local_base_dir /experiment_name/ mouse_name / foldername
        local_dir.mkdir(parents=True, exist_ok=True)

        return local_dir, nas_dir, foldername, today_str

    def transfer_local_to_nas(self, local_dir: Path, nas_dir: Path) -> None:
        if not local_dir.exists():
            raise RuntimeError(f"Local dir does not exist: {local_dir}")
        nas_dir.mkdir(parents=True, exist_ok=True)

        for item in local_dir.iterdir():
            src = item
            dst = nas_dir / item.name
            if src.is_dir():
                shutil.copytree(src, dst, dirs_exist_ok=True)
            else:
                shutil.copy2(src, dst)

    def delete_local(self, local_dir: Path) -> None:
        if local_dir.exists():
            shutil.rmtree(local_dir, ignore_errors=False)


# =============================================================================
# High-level SessionManager
# =============================================================================

ConfirmFn = Callable[[str, str], bool]


class SessionManager:
    def __init__(
        self,
        db: RigDBClient,
        storage: SessionStorageManager,
        *,
        datarecord: Optional[DataRecordCSV] = None,
        tz_name: str = "America/Chicago",
    ):
        self.db = db
        self.storage = storage
        self.datarecord = datarecord
        self.tz = ZoneInfo(tz_name)

    def load_rig_options(
        self
    ):
        rig_names:  list[str] = []
        rig_names.append("PPS_training_Rig_1")
        rig_names.append("PPS_training_Rig_2")
        rig_names.append("PPS_training_Rig_3")

        return rig_names
    # ---- mouse list helpers ----

    def load_mice_options(
        self,
        experiment_id: int,
        *,
        fallback_csv_path: Optional[str | Path] = None,
        include_new_mouse_option: bool = True,
    ) -> tuple[list[str], Optional[dict[str, int]]]:
        try:
            mice = self.db.get_mice_for_experiment(experiment_id)
            if not mice:
                raise RuntimeError("DB returned no mice for this experiment.")
            return build_mouse_dropdown(mice)
        except Exception as e:
            print(f"[db] WARNING: could not load mice from DB ({e}). Falling back to CSV.")

        names: list[str] = []
        if fallback_csv_path is not None:
            try:
                with open(Path(fallback_csv_path), "r", newline="", encoding="utf-8") as f:
                    reader = csv.reader(f)
                    next(reader, None)
                    for row in reader:
                        if row and row[0]:
                            names.append(str(row[0]).strip())
            except Exception as ee:
                print(f"Warning reading {fallback_csv_path}: {ee}")

        names = sorted(set([n for n in names if n]))
        if include_new_mouse_option:
            names.append("New Mouse")
        return names, None

    def parse_selected_mouse(self, selected_option: str, option_to_id: Optional[dict[str, int]]) -> MouseSelection:
        if option_to_id is None:
            return MouseSelection(mouse_name=selected_option.strip(), mouse_id=None, from_db=False)
        mouse_id = int(option_to_id[selected_option])
        mouse_name = parse_mouse_name_from_option(selected_option)
        return MouseSelection(mouse_name=mouse_name, mouse_id=mouse_id, from_db=True)

    # ---- dropdown loaders ----

    def load_experimenters(self) -> list[ExperimenterRow]:
        return self.db.get_experimenters()

    def load_session_types(self) -> list[SessionTypeRow]:
        return self.db.get_session_types()

    def get_or_create_experimenter_id(self, experimenter_name: str, experimenter_email: Optional[str] = None) -> int:
        name_norm = (experimenter_name or "").strip()
        if not name_norm:
            raise DBClientError("experimenter_name is required")

        for row in self.db.get_experimenters():
            if row.experimenter_name.strip().casefold() == name_norm.casefold():
                return int(row.experimenter_id)

        created = self.db.create_experimenter(name_norm, experimenter_email=experimenter_email)
        return int(created.experimenter_id)

    def get_or_create_session_type_id(self, session_type_name: str) -> int:
        name_norm = (session_type_name or "").strip()
        if not name_norm:
            raise DBClientError("session_type_name is required")

        for row in self.db.get_session_types():
            if row.session_type_name.strip().casefold() == name_norm.casefold():
                return int(row.session_type_id)

        created = self.db.create_session_type(name_norm)
        return int(created.session_type_id)

    # ---- prior-session helpers ----

    def warn_if_unanalyzed_last_session(
        self,
        *,
        mouse_id: int,
        experiment_id: int,
        confirm: ConfirmFn,
        fields_to_show: Optional[list[tuple[str, str]]] = None,
    ) -> None:
        last_all = self.db.get_last_session(
            mouse_id=mouse_id,
            experiment_id=experiment_id,
            require_analyzed=False,
        )
        if not last_all or last_all.is_analyzed:
            return

        p = last_all.parameters or {}
        fields_to_show = fields_to_show or [
            ("time_for_stimuli_ms", "time_for_stimuli_ms"),
            ("number_for_0_lag", "number_for_0_lag"),
            ("max_duration_ms", "max_duration_ms"),
            ("wheel_gain", "wheel_gain"),
        ]

        lines = [
            f"The most recent session (DB Session ID: {last_all.session_id}) has NOT been analyzed.",
            "",
            "Parameters from this unanalyzed session:",
        ]
        for label, key in fields_to_show:
            lines.append(f"  - {label}: {p.get(key, 'N/A')}")
        lines += ["", "Continue anyway?"]

        if not confirm("WARNING: Unanalyzed Session", "\n".join(lines)):
            raise SessionAborted("User aborted due to unanalyzed-session warning.")

    def get_next_params(self, *, mouse_id: int, experiment_id: int,experiment_name:str, defaults: dict[str, Any]) -> dict[str, Any]:
        out = dict(defaults)
        last_analyzed = self.db.get_last_session(
            mouse_id=mouse_id,
            experiment_name = experiment_name,
            experiment_id=experiment_id,
            require_analyzed=True,
        )
        if last_analyzed and isinstance(last_analyzed.next_session_parameters, dict):
            out.update(last_analyzed.next_session_parameters)
        return out

    # ---- reward helpers ----

    def apply_reward_policy(
        self,
        parameters: dict[str, Any],
        *,
        rig_id: Optional[int],
        target_reward_ul_override: Optional[float] = None,
        enabled: bool = True,
        put_under_key: str = "reward",
    ) -> Optional[RigRewardPolicy]:
        if not enabled:
            return None

        if rig_id is None:
            policy = RigRewardPolicy(
                rig_id=-1,
                target_reward_ul=(float(target_reward_ul_override) if target_reward_ul_override is not None else None),
                computed_valve_ms=None,
                reward_warning="Warning: rig_id is None; cannot compute valve duration.",
                calibration_id=None,
                performed_at=None,
                cal_min_ul=None,
                cal_max_ul=None,
                closest_ul=None,
                min_ms=None,
                max_ms=None,
            )
        else:
            policy = self.db.get_rig_reward_policy(rig_id, target_reward_ul=target_reward_ul_override)

        block = {
            "target_reward_ul": policy.target_reward_ul,
            "reward_open_duration_ms": policy.computed_valve_ms,
            "warning": policy.reward_warning,
            "calibration_id": policy.calibration_id,
            "performed_at": policy.performed_at,
            "cal_min_ul": policy.cal_min_ul,
            "cal_max_ul": policy.cal_max_ul,
            "closest_ul": policy.closest_ul,
            "min_ms": policy.min_ms,
            "max_ms": policy.max_ms,
        }

        if put_under_key:
            parameters[put_under_key] = block
        else:
            parameters.update(block)

        return policy

    # ---- session lifecycle ----

    def begin_session(
        self,
        *,
        mouse_name: str,
        mouse_id: Optional[int],
        experiment_name: str,
        experiment_id: int,
        rig_id: Optional[int],
        parameters: dict[str, Any],
        fallback_session_num: int,
        session_at: Optional[datetime] = None,
        experimenter_id: Optional[int] = None,
        session_type_id: Optional[int] = None,
    ) -> SessionContext:
        session_at = session_at or datetime.now(self.tz)

        session_id: Optional[int] = None
        if mouse_id is not None:
            try:
                session_id = self.db.create_session(
                    mouse_id=mouse_id,
                    experiment_name = experiment_name, 
                    experiment_id=experiment_id,
                    session_at=session_at,
                    rig_id=rig_id,
                    experimenter_id=experimenter_id,
                    session_type_id=session_type_id,
                    parameters=parameters,
                    links=None,
                )
                print(f"[db] Created session_id={session_id}")
                print(f"[db] Follow live session data at: {self.db.base_url}/sessions/{session_id}")
            except DBClientError as e:
                print(f"[db] WARNING: could not create session ({e}). Continuing offline.")
                session_id = None

        session_num = int(session_id) if session_id is not None else int(fallback_session_num)

        local_dir, nas_dir, foldername, _ = self.storage.make_folders(mouse_name, experiment_name, session_num)

        patched_parameters = dict(parameters)
        patched_parameters["paths"] = {
            "local_folder": to_windows_path(local_dir),
            "nas_folder": to_windows_path(nas_dir),
        }

        if session_id is not None:
            try:
                self.db.patch_session(
                    session_id,
                    parameters=patched_parameters,
                    experimenter_id=experimenter_id,
                    session_type_id=session_type_id,
                )
            except Exception as e:
                print(f"[db] WARNING: could not patch session paths: {e}")

        smb_link = build_smb_link(self.storage.smb_base_unc, mouse_name, foldername)

        return SessionContext(
            mouse_name=mouse_name,
            mouse_id=mouse_id,
            experiment_name = experiment_name,
            experiment_id=experiment_id,
            rig_id=rig_id,
            experimenter_id=experimenter_id,
            session_type_id=session_type_id,
            session_id=session_id,
            session_num=session_num,
            session_at=session_at,
            local_dir=local_dir,
            nas_dir=nas_dir,
            foldername=foldername,
            smb_link=smb_link,
            parameters=patched_parameters,
        )

    def finalize_session(
        self,
        ctx: SessionContext,
        *,
        performance: Optional[dict[str, Any]] = None,
        next_session_parameters: Optional[dict[str, Any]] = None,
        append_datarecord_row: Optional[list[Any]] = None,
        transfer_to_nas: bool = True,
        delete_local: bool = True,
        mark_analyzed: bool = True,
        links_override: Optional[str] = None,
    ) -> None:
        if self.datarecord is not None and append_datarecord_row is not None:
            self.datarecord.append_row(ctx.mouse_name, append_datarecord_row)

        if transfer_to_nas:
            print("Transferring files from local to NAS...")
            try:
                self.storage.transfer_local_to_nas(ctx.local_dir, ctx.nas_dir)
                print("Transfer complete.")
            except Exception as e:
                print(f"Error during file transfer: {e}")
                delete_local = False

        if delete_local:
            try:
                self.storage.delete_local(ctx.local_dir)
                print("Local temp folder deleted.")
            except Exception as e:
                print(f"Error deleting local folder: {e}")

        if ctx.session_id is not None:
            links_value = links_override if links_override is not None else ctx.smb_link
            try:
                self.db.patch_session(
                    ctx.session_id,
                    rig_id=ctx.rig_id,
                    experimenter_id=ctx.experimenter_id,
                    session_type_id=ctx.session_type_id,
                    performance=performance,
                    next_session_parameters=next_session_parameters,
                    is_analyzed=bool(mark_analyzed),
                    parameters=ctx.parameters,
                    links=links_value,
                )
                print(f"[db] Patched session_id={ctx.session_id} successfully.")
                print(f"[db] Session finalized at: {self.db.base_url}/sessions/{ctx.session_id}")
            except DBClientError as e:
                print(f"[db] WARNING: could not patch session ({e}).")

    # ---- convenience wrappers ----

    def finalize_analyzed_session(
        self,
        ctx: SessionContext,
        *,
        performance: dict[str, Any],
        next_session_parameters: dict[str, Any],
        append_datarecord_row: Optional[list[Any]] = None,
        transfer_to_nas: bool = True,
        delete_local: bool = True,
        links_override: Optional[str] = None,
    ) -> None:
        self.finalize_session(
            ctx,
            performance=performance,
            next_session_parameters=next_session_parameters,
            append_datarecord_row=append_datarecord_row,
            transfer_to_nas=transfer_to_nas,
            delete_local=delete_local,
            mark_analyzed=True,
            links_override=links_override,
        )

    def finalize_unanalyzed_session(
        self,
        ctx: SessionContext,
        *,
        append_datarecord_row: Optional[list[Any]] = None,
        transfer_to_nas: bool = True,
        delete_local: bool = True,
        links_override: Optional[str] = None,
    ) -> None:
        self.finalize_session(
            ctx,
            performance=None,
            next_session_parameters=None,
            append_datarecord_row=append_datarecord_row,
            transfer_to_nas=transfer_to_nas,
            delete_local=delete_local,
            mark_analyzed=False,
            links_override=links_override,
        )